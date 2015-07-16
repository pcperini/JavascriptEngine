# JavascriptEngine
A Swift interface for bridging to WebKit Javascript, without wanting to kill yourself or others.

## To use...

```swift
let engine = JSEngine(sourceString: "function foo(bar) {" +
    "engine.fooHandler.postMessage([bar, bar]);" +
"}")

engine.setHandlerForKey("fooHandler") { (bars: [String]) in
    println(bars.map { "why would want to do this?" })
}

engine.load {
    engine.callFunction("foo", args: ["i don't know"])
}
```