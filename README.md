# Serializer 1.0.0

The Serializer call includes two `static` methods that allow you serialize (nearly) any Squirrel object into a blob, and deserialize perviously serialized objects. This is particulairly useful if you're planning to store information with [hardware.spiflash](https://electricimp.com/docs/api/hardware/spiflash) or the with the [SPIFlash Library](https://github.com/electricimp/spiflash/tree/v1.0.0).

*NOTE:* The *Serializer* class only uses `static` methods, and as a result does not to be initialized through a constructor.

**To add this library to your project, add `#require "Serializer.class.nut:1.0.0"`` to the top of your device code.**

You can view the library’s source code on [GitHub](https://github.com/electricimp/serializer/tree/v1.0.0).

## Serializable Squirrel

The Serializer class currently supports the following types:

- [arrays](https://electricimp.com/docs/squirrel/array/)
- [blobs](https://electricimp.com/docs/squirrel/blob/)
- [booleans](https://electricimp.com/docs/squirrel/bool/)
- [floats](https://electricimp.com/docs/squirrel/float/)
- [integers](https://electricimp.com/docs/squirrel/integer/)
- [strings](https://electricimp.com/docs/squirrel/string/)
- [tables](https://electricimp.com/docs/squirrel/table/)
- `null`

The Serializer cannot serialize the following types:

- `function` - Functions / function pointers.
- `instance` - Class instances.
- `meta` - Meta objects such as *device* and *hardware*.

## Class Methods

### Serializer.serialize(*obj, [prefix]*)

The *Serializer.serialize* method allows you to transform an arbitrary Squirrel object (*obj*) into a blob.

```squirrel
# require "Serializer.class.nut:1.0.0"

local data = {
    "foo": "bar",
    "timestamps": [ 1436983175, 1436984975, 1436986775, 1436988575, 1436990375],
    "readings": [ 32.5, 33.6, 32.8, 32.9, 32.5 ],
    "otherData": {
        "state": true,
        "test": "test"
    }
}

local serializedData = Serializer.serialize(data);

// Write the data to SPI Flash @ 0x0000
spiFlash.enable();
spiFlash.erasesector(0x0000);
spiFlash.write(0x0000, serializedData, SPIFLASH_PREVERIFY | SPIFLASH_POSTVERIFY);
spiFlash.disable();
```

If a *prefix* was passed to the method, the Serializer will write this data at the beginning of the blob. Immediatly proceeding the prefix data, the Serializer will write 3 bytes of header information: a 16-bit unsigned integer representing the length of the serialized data, and an 8-bit unsigned integer representing a CRC.

| Byte | Description                  |
| ---- | ---------------------------- |
| 0    | The lower byte of the length |
| 1    | The upper byte of the length |
| 2    | The CRC byte                 |

**NOTE:** The 16-but length value does include the length of the prefix (if included) or the header data (3 bytes).

### Serializer.deserialize(*serializedBlob, [prefix]*)

The *Serializer.deserialize* method will deserialize a blob that was previous serialized with the *Serializer.serialize* method. If the blob was serialized with a *prefix*, the same *prefix* must be passed into the *Serializer.deserialize* method.

```squirrel
# require "Serializer.class.nut:1.0.0"

// Setup SpiFlash object
// ...

spiFlash.enable();

// Read the header information
local dataBlob = spiFlash.read(0x00, 3);
// Get the length from the first two bytes
local len = dataBlob.readn('w');

// Move to the end of the blob
dataBlob.seek(0, 'e');

// Read the length of the data starting at the end of the header
spiFlash.readintoblob(0x03, dataBlob, len);

// Disable the SPIFlash since we're done
spiFlash.disable();

// Deserialize the blob
local data = Serializer.deserialize(dataBlob);



// Log some data to make sure it worked:
server.log(data.foo);               // bar
server.log(data.otherData.state);   // true
server.log(data.otherData.test);    // test

server.log("Readings:");
for(local i = 0; i < data.timestamps.len(); i++) {
    server.log(data.timestamps[i] + ": " + data.readings[i]);
}

```

# License

The Serializer class is licensed under [MIT License](https://github.com/electricimp/serializer/tree/master/LICENSE).
