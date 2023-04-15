
import type { MtEntityDef, MtObjRef, MtPlayer, MtPointedThing, MtVec3 } from "@repcomm/mt-api";
import type {} from "@repcomm/mt-3d-armor-api";

let modname = minetest.get_current_modname();

let modpath = minetest.get_modpath(modname);

dofile(`${modpath}/vec.lua`);
dofile(`${modpath}/evt.lua`);

function lerp(from: number, to: number, by: number) {
  return from * (1 - by) + to * by;
}
function lerpClamped(from: number, to: number, by: number) {
  let result = from * (1 - by) + to * by;
  if (result < from) result = from;
  if (result > to) result = to;
  return result;
}

let wingsEntityName = `${modname}:wings_entity`;

interface WingsProps {
  _playername?: string;

  _pitch: number;
  _yaw: number;

  _outVelocity: MtVec3;
  _vel: MtVec3;

  _isGliding: boolean;
  _wasGliding: boolean;
  _glideTime: number;
  _glide: (dtime: number) => void;
  _setGliding(isGliding: boolean): void;
  _updateAttachment(this: WingsEnRef, player: MtPlayer): void;

  _speed: number;
  _groundCalcSpeedMax: number;
  _timeLastJump: number;

  _wingFoldedDeg: number;
  _wingSpanDeg: number;
  _wingStressDeg: number;
  _wingRelaxDeg: number;
}

interface WingsEnDef extends Partial<MtEntityDef>, WingsProps {

}

interface WingsEnRef extends MtObjRef, WingsProps {
}

function entityOnGround(en: MtObjRef, ySearchDown: number = 1.5): boolean {
  const from = en.get_pos();
  const to = { x: from.x, y: from.y - ySearchDown, z: from.z };

  let hits = minetest.raycast(from, to);

  let hit: MtPointedThing | undefined;
  for (let hit of hits) {
    if (hit.type === "node") return true;
  }
  // while ((hit = hits.next()) !== undefined) {
  // }
  return false;
}

const RAD2DEG = 57.29578;

const v3zero = { x: 0, y: 0, z: 0 };
const wingPos = { x: 0, y: -2.7809, z: 5.10305 };

interface WingsEquipChangeEvt {
  player: MtPlayer;
  wing?: WingsEnRef;
  equipped: boolean;
}

interface WingsGlideChangeEvt {
  player: MtPlayer | undefined;
  wings: WingsEnRef;
  isGliding: boolean;
}

interface WingsEventMap {
  equipchange: WingsEquipChangeEvt;
  glidechange: WingsGlideChangeEvt;
}

const wings = {
  events: new EventDispatcher<WingsEventMap>(),

  all: new Set<WingsEnRef>,

  getPlayerWingEntity(this: void, playername: string): WingsEnRef | undefined {
    for (let wing of wings.all) {
      if (wing._playername === playername) return wing;
    }
    return undefined;
  },
  isWingUsed(this: void, wing: WingsEnRef): boolean {
    return wing._playername !== undefined;
  },
  clearWing(this: void, wing: WingsEnRef): void {
    wing.object.remove();
    wings.all.delete(wing);
  },
  clearUnused(this: void) {
    for (let wing of wings.all) {
      if (!wings.isWingUsed(wing)) {
        wing.object.remove();
        wings.all.delete(wing);
      }
    }
  },
  clearAll(this: void): void {
    for (let id in minetest.luaentities) {
      let luaen = minetest.luaentities[id];
      if (luaen.name === wingsEntityName) {
        luaen.object.remove();
        wings.all.delete(luaen as WingsEnRef);
      }
    }
  },
  getOrCreate(this: void, player: MtPlayer): WingsEnRef {
    let playername = player.get_player_name();
    let result = wings.getPlayerWingEntity(playername);

    if (result === undefined) {
      let pos = player.get_pos();

      let en = minetest.add_entity(pos, wingsEntityName);
      result = en.get_luaentity() as WingsEnRef;
      result._playername = playername;
      wings.all.add(result);

      result._updateAttachment(player);
    }

    return result;
  },
  clearPlayerWingEntity(this: void, playername: string): void {
    let wing = wings.getPlayerWingEntity(playername);
    if (wing === undefined) return;
    wings.clearWing(wing);
  }
};

wings.events.listen("glidechange", (evt) => {
  minetest.chat_send_player(evt.player!.get_player_name(), `You ${evt.isGliding ? "started" : "stopped"} gliding`);
});

function wings_onstep(this: WingsEnRef, dtime: number) {
  let player: MtPlayer | undefined;

  if (this._playername === undefined) {
    this._setGliding(false); //no player assigned, probably do some recycle or GC later
    return;
  }

  player = minetest.get_player_by_name(this._playername!);
  if (player === undefined) {
    this._setGliding(false); //player offline?
    return;
  }

  let { jump, sneak } = player.get_player_control();
  const t = minetest.get_gametime();

  if (this._isGliding) {
    if (sneak) {
      this._setGliding(false);
    }
  } else {
    if (jump && t - this._timeLastJump > 1) {

      minetest.after(0.2, () => {
        this._timeLastJump = t;

        if (!entityOnGround(player!, 2)) {
          this._setGliding(true);
        }
      });
    }
  }

  if (this._isGliding) {
    //get all flying inputs
    this._yaw = player!.get_look_horizontal();
    this._pitch = player!.get_look_vertical();
    //include previous velocity
    this._vel = this.object.get_velocity();

    //calculate our speed
    this._speed = vec.copy(this._vel).magnitude();

    //calculate flying forces and apply them
    this._glide(dtime);

    //try landing
    if (this._speed < this._groundCalcSpeedMax && entityOnGround(this.object, 0.6)) this._setGliding(false);
  }
}

let wingsEnDef: WingsEnDef = {
  visual: "mesh",
  mesh: "wings.x",
  textures: ["wings_entity.png"],
  backface_culling: false,

  collisionbox: [-0.2, -0.45, -0.2, 0.2, 0.1, 0.2],
  physical: true,

  _playername: undefined,

  _yaw: 0,
  _pitch: 0,
  _glideTime: 0,
  _outVelocity: { x: 0, y: 0, z: 0 },
  _vel: { x: 0, y: 0, z: 0 },

  _wingFoldedDeg: 75,
  _wingSpanDeg: 0,
  _wingStressDeg: 15,
  _wingRelaxDeg: 0,

  _speed: 0,
  _groundCalcSpeedMax: 12,

  /**True for every frame the wings are gliding*/
  _isGliding: false,
  /**_isGliding, but for last frame instead of current*/
  _wasGliding: false,

  _timeLastJump: 0,

  //@ts-expect-error - WingsEnRef inherits from MtObjRef, just haven't gotten the types right exactly
  on_activate(this: WingsEnRef, sd, dtime) {
    minetest.after(0.1, () => {
      if (this._playername === undefined) {
        this.object.remove(); //cleanup after restart.. ugly hack but its not that bad
        //essentially we haven't used staticdata to save lua entity properties and so _playername will be undefined after a restart
        //we don't care cause we spawn them as needed anyways, so DELETE 'em }:D
      }
    });
  },

  _glide(this: WingsEnRef, dtime: number) {
    this.object.set_bone_position("root", v3zero, {
      y: 0,
      x: 90 + (this._pitch * RAD2DEG),
      z: -(this._yaw * RAD2DEG)
    });

    let wingsSpeedBend = lerp(this._wingSpanDeg, this._wingFoldedDeg, this._speed / 60);
    let wingsStressBend = lerpClamped(this._wingRelaxDeg, this._wingStressDeg, this._speed / 8);

    this.object.set_bone_position("left", wingPos, {
      x: 0,
      y: wingsSpeedBend,
      z: wingsStressBend
    });
    this.object.set_bone_position("right", wingPos, {
      x: 0,
      y: -wingsSpeedBend,
      z: -wingsStressBend
    });

    //math modified from
    //https://gist.github.com/RepComm/c7d7674629c7e27f308786866c495e77 
    //which is modified from
    //https://gist.github.com/samsartor/a7ec457aca23a7f3f120
    const yawcos = Math.cos(-this._yaw - Math.PI);
    const yawsin = Math.sin(-this._yaw - Math.PI);
    const pitchcos = Math.cos(this._pitch);
    const pitchsin = Math.sin(this._pitch);
    const lookX = yawsin * -pitchcos;
    const lookY = -pitchsin;
    const lookZ = yawcos * -pitchcos;
    const hvel = Math.sqrt(this._vel.x * this._vel.x + this._vel.z * this._vel.z);
    const hlook = pitchcos; //Math.sqrt(lookX * lookX + lookZ * lookZ)
    const sqrpitchcos = pitchcos * pitchcos; //In MC this is multiplied by Math.min(1.0, Math.sqrt(lookX * lookX + lookY * lookY + lookZ * lookZ) / 0.4), don't ask me why, it should always =1

    //From here on, the code is identical to the code found in net.minecraft.entity.EntityLivingBase.moveEntityWithHeading(float, float) or rq.g(float, float) in obfuscated 15w41b
    this._outVelocity.y += -0.08 + sqrpitchcos * 0.06;

    if (this._outVelocity.y < 0 && hlook > 0) {
      let yacc = this._vel.y * -0.1 * sqrpitchcos;
      this._vel.y += yacc;
      this._vel.x += lookX * yacc / hlook;
      this._vel.z += lookZ * yacc / hlook;
    }
    if (this._pitch < 0) {
      let yacc = hvel * -pitchsin * 0.04;
      this._vel.y += yacc * 3.5;
      this._vel.x -= lookX * yacc / hlook;
      this._vel.z -= lookZ * yacc / hlook;
    }
    if (hlook > 0) {
      this._vel.x += (lookX / hlook * hvel - this._vel.x) * 0.1;
      this._vel.z += (lookZ / hlook * hvel - this._vel.z) * 0.1;
    }

    this._vel.x *= 0.99;
    this._vel.y *= 0.98;
    this._vel.z *= 0.99;

    this._outVelocity.x = this._vel.x;
    this._outVelocity.y = this._vel.y;
    this._outVelocity.z = this._vel.z;

    this._glideTime += dtime;

    this._outVelocity.y -= 0.98; //gravity

    this.object.set_velocity(this._outVelocity);
  },
  _updateAttachment(this: WingsEnRef, player: MtPlayer) {
    if (this._isGliding) {
      this.object.set_pos(player!.get_pos());
      
      this.object.set_detach();

      minetest.after(0.2, ()=>{
        let pv = player.get_velocity();
        this.object.set_velocity(pv);
        vec.copy(pv).store(this._vel);
        player.set_attach(this.object, "mount", v3zero, v3zero);
      });
      
    } else {
      player.set_detach();

      minetest.after(0.2, ()=>{
        this.object.set_attach(player, "Body", v3zero, v3zero);
        // attachments.attach(this.object, player, "Body", v3zero, v3zero, ()=>{
        this.object.set_bone_position("root", v3zero, { x: -10, y: 0, z: 0 });
  
        this.object.set_bone_position("left", wingPos, {
          x: 0,
          y: this._wingFoldedDeg,
          z: this._wingRelaxDeg
        });
        this.object.set_bone_position("right", wingPos, {
          x: 0,
          y: -this._wingFoldedDeg,
          z: -this._wingRelaxDeg
        });
      });
    }
  },
  _setGliding(this: WingsEnRef, isGliding: boolean) {
    let player: MtPlayer | undefined;
    if (!this._playername) return;
    player = minetest.get_player_by_name(this._playername);
    if (!player) return;

    this._wasGliding = this._isGliding;
    this._isGliding = isGliding;


    if (this._isGliding !== this._wasGliding) {
      this._updateAttachment(player);

      wings.events.fire("glidechange", {
        isGliding,
        player,
        wings: this
      });
    }

  },

  // @ts-expect-error - WingsEnRef vs WingsEnDef, basically mt-api needs some adjustment somehow - no actual issue present
  on_step: wings_onstep
};

minetest.register_entity(wingsEntityName, wingsEnDef);

let wingsItemName = `${modname}:wings_feather`;
let wingsInvTex = `${modname}_inv_wings_feather.png`;

armor.register_armor(wingsItemName, {
  armor_groups: { fleshy: 1 },
  groups: { armor_torso: 1 },
  damage_groups: { flammable: 1, fluffy: 1 },
  description: "You're free as a bird",
  inventory_image: wingsInvTex
});

minetest.register_on_leaveplayer((p, timedout) => {
  let pname = p.get_player_name();
  let wing = wings.getPlayerWingEntity(pname);
  if (wing === undefined) return;
  wings.clearWing(wing);
});

wings.events.listen("equipchange", (evt) => {
  minetest.chat_send_player(evt.player.get_player_name(), `You ${evt.equipped ? "equipped" : "unequipped"} wings`);
});

armor.register_on_equip((p, index, stack) => {
  // let pname = p.get_player_name();

  if (stack.get_name() === wingsItemName) {
    let wing = wings.getOrCreate(p);

    wings.events.fire("equipchange", {
      equipped: true,
      player: p,
      wing
    });
  }
});

armor.register_on_unequip((player, index, stack) => {
  let pname = player.get_player_name();

  if (stack.get_name() === wingsItemName) {
    wings.clearPlayerWingEntity(pname);

    wings.events.fire("equipchange", {
      equipped: false,
      player: player
    });
  }
});

minetest.register_craft({
  type: "shaped",
  output: wingsItemName,
  recipe: [
    ["", "", ""],
    ["", "default:stone", ""],
    ["", "", ""]
  ]
});

