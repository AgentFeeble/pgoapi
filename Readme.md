# Swift Pokemon GO API

This is still a work in progress. The only working function at the moment is login via PTC, and downloading the following data:

- Player
- Hatched eggs
- Inventory
- Badges
- Settings
- Map Objects

I'm adding functionality as I need it. Feel free to contribute any API calls I haven't already implemented.

####Note
Due to copyright reasons, the Niantic encryption functions used for the requests are not included in the repo. Before using the api, you will need to set a static function pointer for `PgoEncryption.encrypt`, which will do the necessary encryption. Look at the example project to see how to do it using the `encrypt.c` file that can be found floating around the depths of the Internet.

# Installation
Note, when integrating with cocoa pods, you need to make sure to use a version of [ProtocolBuffers-Swift v3.0](https://github.com/alexeyxo/protobuf-swift), compatible with Swift 2.0. Include this in your pod file:

`pod 'ProtocolBuffers-Swift', :git => 'https://github.com/alexeyxo/protobuf-swift', :branch => 'ProtoBuf3.0-Swift2.0'`

## Credit
A big shout out to all the devs involved in figuring out `Unknown6` and other hashes, and to keyphact and contributors for the excellent [pgoapi fork](https://github.com/keyphact/pgoapi) showcasing the necessary steps to get the API working again. Thank you to all the open source projects working together to make this possible, including, but not limited to Luke Sapan, with his  [Swift API](https://github.com/lsapan/pgoapi-swift)  that gave me a push in the right direction, and AeonLucid for providing and maintaining the [POGO Protocol Buffer files](https://github.com/AeonLucid/POGOProtos).
