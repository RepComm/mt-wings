
interface EventDemo {
  msg: string;
  somethingelse?: number;
}

interface EventMapDemo {
  thingHappens: EventDemo;
}

interface EventCallback<T> {
  (evt: T): boolean|void;
}

class EventDispatcher<EventMap> {
  listeners: Map<string, Set<EventCallback<keyof EventMap>>>;

  constructor () {
    this.listeners = new Map();
  }
  private getListenerType<K extends keyof EventMap> (type: K, create: boolean = false): Set<EventCallback<EventMap[K]>>|undefined {
    let result = this.listeners.get(type as string);
    if (!result) {
      if (create) {
        result = new Set();
        this.listeners.set(type as string, result);
      } else {
        return undefined;
      }
    }
    return result as any;
  }
  listen<K extends keyof EventMap>(type: K, cb: EventCallback<EventMap[K]>): this {
    this.getListenerType(type, true)!.add(cb as any);
    return this;
  }
  deafen<K extends keyof EventMap> (type: K, cb: EventCallback<EventMap[K]>): this {
    let lt = this.getListenerType(type);
    if (lt) lt.delete(cb);
    return this;
  }
  fire<K extends keyof EventMap> (type: K, evt: EventMap[K], cancelable: boolean = true): this {
    let lt = this.getListenerType(type, false);
    if (!lt) return this;

    for (let cb of lt) {
      //@ts-ignore
      let result = cb(evt) as boolean;
      if (result && cancelable) break;
    }
    return this;
  }
}
