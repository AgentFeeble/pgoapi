# Swift Pokemon GO API

![Swift Version](https://img.shields.io/badge/Swift-3.0.x-orange.svg)
![Pokemon GO API](https://img.shields.io/badge/API-v0.45.0-brightgreen.svg)
![PokeFarmer Hash Server](https://img.shields.io/badge/PokeFarmer%20Hash%20Server-v121__2-brightgreen.svg)

This is still a work in progress. The only working function at the moment is login via PTC, and downloading the following data:

- Player
- Hatched eggs
- Inventory
- Badges
- Settings
- Map Objects

I'm adding functionality as I need it. Feel free to contribute any API calls I haven't already implemented.

####Note
Due to copyright reasons, the Niantic encryption and hashing functions used for the requests are not included in the repo. Before using the api, you will need to set a static function pointer for `PgoEncryption.encrypt`, which will perform the necessary encryption. Look at the example project to see how to do it using the `encrypt.c` file that can be found floating around the depths of the Internet.
Remember that the different API versions use a slightly different encrypt function, so you will have to use different versions of the encrypt function when using `NativeHashGenerator` or `PokeFarmerHashGenerator`

# Installation
Note, when integrating with cocoa pods, you need to make sure to use a version of [ProtocolBuffers-Swift v3.0](https://github.com/alexeyxo/protobuf-swift), compatible with Swift 3.0. Include this in your pod file:

`pod 'ProtocolBuffers-Swift', :git => 'https://github.com/alexeyxo/protobuf-swift', :branch => 'ProtoBuf3.0-Swift3.0'`

## Credit
A big shout out to all the devs involved in figuring out `Unknown6` and other hashes, and to keyphact and contributors for the excellent [pgoapi fork](https://github.com/keyphact/pgoapi) showcasing the necessary steps to get the API working again. Thank you to all the open source projects working together to make this possible, including, but not limited to Luke Sapan, with his  [Swift API](https://github.com/lsapan/pgoapi-swift)  that gave me a push in the right direction, and AeonLucid for providing and maintaining the [POGO Protocol Buffer files](https://github.com/AeonLucid/POGOProtos).