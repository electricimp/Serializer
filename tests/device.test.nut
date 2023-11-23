/**
 * Serializer Library test cases
 *
 */
@include "Serializer.class.nut"

class TestClass {
    _a = null;
    constructor(){
        _a = 42;
    }
}

class SerializerTestCase extends ImpTestCase {

    _rawData = null;
    _serializedData = null;
    _validData = null;

    /**
     * Get the imp Type (impp04m or imp006)
     */
    function setUp() {

        // Contains all valid types
        _rawData = {
            "foo": "bar",
            "timestamps": [ 1436983175, 1436984975, 1436986775, 1436988575, 1436990375],
            "readings": [ 32.5, 33.6, 32.8, 32.9, 32.5 ],
            "otherData": {
                "state": true,
                "test": "test"
            }
        };

        // Data generated from the above using `Serializer.class.nut:1.0.0`
        local data = [0xe0,0x00,0xe5,0x74,0x00,0x04,0x73,0x00,0x08,0x72,0x65,0x61,0x64,0x69,0x6e,0x67,0x73,0x61,0x00,0x05,0x69,0x00,0x01,0x30,0x46,0x00,0x04,0x00,0x00,0x02,0x42,0x69,0x00,0x01,0x31,0x46,0x00,0x04,0x66,0x66,0x06,0x42,0x69,0x00,0x01,0x32,0x46,0x00,0x04,0x33,0x33,0x03,0x42,0x69,0x00,0x01,0x33,0x46,0x00,0x04,0x9a,0x99,0x03,0x42,0x69,0x00,0x01,0x34,0x46,0x00,0x04,0x00,0x00,0x02,0x42,0x73,0x00,0x09,0x6f,0x74,0x68,0x65,0x72,0x44,0x61,0x74,0x61,0x74,0x00,0x02,0x73,0x00,0x04,0x74,0x65,0x73,0x74,0x73,0x00,0x04,0x74,0x65,0x73,0x74,0x73,0x00,0x05,0x73,0x74,0x61,0x74,0x65,0x62,0x01,0x73,0x00,0x0a,0x74,0x69,0x6d,0x65,0x73,0x74,0x61,0x6d,0x70,0x73,0x61,0x00,0x05,0x69,0x00,0x01,0x30,0x69,0x00,0x0a,0x31,0x34,0x33,0x36,0x39,0x38,0x33,0x31,0x37,0x35,0x69,0x00,0x01,0x31,0x69,0x00,0x0a,0x31,0x34,0x33,0x36,0x39,0x38,0x34,0x39,0x37,0x35,0x69,0x00,0x01,0x32,0x69,0x00,0x0a,0x31,0x34,0x33,0x36,0x39,0x38,0x36,0x37,0x37,0x35,0x69,0x00,0x01,0x33,0x69,0x00,0x0a,0x31,0x34,0x33,0x36,0x39,0x38,0x38,0x35,0x37,0x35,0x69,0x00,0x01,0x34,0x69,0x00,0x0a,0x31,0x34,0x33,0x36,0x39,0x39,0x30,0x33,0x37,0x35,0x73,0x00,0x03,0x66,0x6f,0x6f,0x73,0x00,0x03,0x62,0x61,0x72];

        _validData = blob(data.len());
        _validData.seek(0, 'b');
        foreach(value in data) {
            _validData.writen(value, 'b');
        }

        _serializedData = Serializer.serialize(_rawData);
    }

    function testSerialize() {

        // CHECK OUTPUT CORRECT
        this.assertTrue(_serializedData.len() == _validData.len());
    }

    function testDeserialize() {

        // DESERIALIZE DATA SERIALIZED USING THE LATEST VERSION
        local outData = Serializer.deserialize(_serializedData);
        _compareDeserialized(outData);

        // DESERIALIZE DATA SERIALIZED USING V.1.0.0
        outData = Serializer.deserialize(_validData);
        _compareDeserialized(outData);
    }

    function testGoodTypes() {

        // Test valid serializable types that are not included in `_rawData`
        local td = {
            "good_blob": blob(128),
            "good_null": null
        };

        // Fill the blob
        for (local i = 0 ; i < 128 ; i++) td.good_blob[i] = 0xFF;

        local od = Serializer.serialize(td);
        local op = Serializer.deserialize(od);
        this.assertTrue(op.good_blob.len() == 128);
        this.assertTrue(op.good_blob[65] == 0xFF);

        local count = 0;
        foreach (value in op.good_blob) {
            if (value == 0xFF) count++;
        }
        this.assertTrue(count == op.good_blob.len());
        this.assertTrue(op.good_null == null);
    }

    function testBadTypes() {
        /*
        The Serializer cannot serialize the following types:

            - `function` - Functions / function pointers.
            - `instance` - Class instances.
            - `meta`     - Meta objects such as *device* and *hardware*.
        */

        // CLASS INSTANCES
        local tc = TestClass();
        local fn = function(a, b) { return a * b };
        //local mt = ::device;  // Reports `device ` does not exist

        local td = {
            "good_value": true,
            "bad_instance": tc,
            //"bad_meta": mt
        };

        // CHECK SERIALIZER CORRECTLY THROWS
        this.assertThrowsError(function(a) {
            throw Serializer.serialize(a);
        }, this, [td]);

        // FUNCTIONS

        td = {
            "bad_function": fn
        };

        // CHECK SERIALIZER CORRECTLY CONVERTS FUNCTION VALUES TO NULL
        local od = Serializer.serialize(td);
        this.assertTrue(Serializer.deserialize(od).bad_function == null);
    }

    function testPrefixUsage() {

        local pd = Serializer.serialize(_rawData, "\xFF\xFF");

        // PREFIX TOO SHORT
        this.assertThrowsError(function(a, b) {
            throw Serializer.deserialize(a, b);
        }, this, [pd, "\xFF"]);

        // PREFIX MISSING
        this.assertThrowsError(function(a, b) {
            throw Serializer.deserialize(a, b);
        }, this, [pd, null]);

        // PREFIX MISSING
        local op = Serializer.deserialize(pd, "\xFF\xFF");
        _compareDeserialized(op);
    }

    function testBadSerialVarType() {

        // Check that serial data containing an invalid data type throws

        /*
        TODO
        local s = "\00\x01\x\x\x"
        // CHECK SERIALIZER CORRECTLY THROWS
        this.assertThrowsError(function(a) {
            throw Serializer.deserialize(a);
        }, this, [td]);
        */
    }

    function _compareDeserialized(outData) {
        this.assertTrue(outData.otherData.state);
        this.assertTrue(outData.otherData.test == _rawData.otherData.test);
        this.assertTrue(outData.readings[1] == _rawData.readings[1]);
        this.assertTrue(outData.readings[2] == _rawData.readings[2]);
        this.assertTrue(outData.timestamps[4] == _rawData.timestamps[4]);
        this.assertTrue(outData.timestamps[0] == _rawData.timestamps[0]);
        this.assertTrue(outData.foo == _rawData.foo);
    }
}