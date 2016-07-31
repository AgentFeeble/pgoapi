# Swift Pokemon GO API

This is still a work in progress. The only working function at the moment is login via PTC, and downloading the following data:

- Player
- Hatched eggs
- Inventory
- Badges
- Settings
- Map Objects

I'm adding functionality as I need it. Feel free to contribute any API calls I haven't already implemented.

# Installation
Note, when integrating with cocoa pods, you need to make sure to use a version of [ProtocolBuffers-Swift v3.0](https://github.com/alexeyxo/protobuf-swift), compatible with Swift 2.0. Include this in your pod file:

```pod 'ProtocolBuffers-Swift', :git => 'https://github.com/alexeyxo/protobuf-swift', :branch => 'ProtoBuf3.0-Swift2.0'```

## Credit
Thank you to all the open source projects working together to make this possible, including, but not limited to Luke Sapan, with his  [Swift API](https://github.com/lsapan/pgoapi-swift)  that gave me a push in the right direction, and AeonLucid for providing and maintaining the [POGO Protocol Buffer files](https://github.com/AeonLucid/POGOProtos).
