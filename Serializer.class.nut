// Copyright (c) 2015-19 Electric Imp
// Copyright (c) 2020-23 KORE Wireless
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

class Serializer {
    static version = [1,1,0];

    // Serialize a variable of any type into a blob
    static function serialize (obj, prefix = null) {
        // Take a guess at the initial size
        local b = blob(512);
        local header_len = 3;
        local prefix_len = (prefix == null) ? 0 : prefix.len();

        // Write the prefix plus dummy data for length and CRC
        if (prefix_len > 0) {
            foreach (ch in prefix) b.writen(ch, 'b');
        }

        // Write two bytes for length
        b.writen(0, 'w');   // 0x0000
        // Write 1 byte for CRC
        b.writen(0, 'b');   // 0x00

        // Serialise the object
        _serialize(b, obj);

        // Resize the blog as required
        local body_len = b.tell();
        b.resize(body_len);

        // Remove header and prefix from length of body
        body_len -= (header_len + prefix_len);

        // Write the body length and CRC
        b.seek(prefix_len);
        b.writen(body_len, 'w');
        b.writen(LRC8(b, header_len + prefix_len), 'b');

        // Move pointer to start of blob,
        // and return serialized object
        b.seek(0);
        return b;
    }

    // Deserialize a string into a variable
    static function deserialize (s, prefix = null) {
        // Read and check the prefix and header
        local prefix_len = (prefix == null) ? 0 : prefix.len();
        local header_len = 3;
        s.seek(0);

        local pfx = prefix_len > 0 ? s.readblob(prefix_len) : null;
        local len = s.readn('w');
        local crc = s.readn('b');

        if (s.len() != len+prefix_len+header_len) throw "Expected " + (len+prefix_len+header_len) + " bytes (got " + s.len() + " bytes)";
        // Check the prefix
        if (prefix != null && pfx.tostring() != prefix.tostring()) throw "Prefix mismatch";
        // Check the CRC
        local _crc = LRC8(s, prefix_len+header_len);
        if (crc != _crc) throw format("CRC err: 0x%02x != 0x%02x", crc, _crc);
        // Deserialise the rest
        return _deserialize(s, prefix_len+header_len).val;
    }

    static function sizeof(obj, prefix = null) {
        local size = 3; // header
        if (prefix != null) size += prefix.len();
        return size += _sizeof(obj);
    }

    static function _sizeof(obj) {
        switch (typeof obj) {
            case "integer":
                return format("%d", obj).len() + 3
            case "float":
                return 7;
            case "null":
            case "function": // Silently setting this to null
                return 1;
            case "bool":
                return 2;
            case "blob":
            case "string":
                return obj.len()+3;
            case "table":
            case "array":
                local size = 3;
                foreach ( k,v in obj ) {
                    size += _sizeof(k) + _sizeof(v)
                }
                return size;
            default:
                throw ("Can't serialize " + typeof obj);
        }
    }

    // Calculates an 8-bit CRC
    static function LRC8 (data, offset = 0) {
        local LRC = 0x00;
        for (local i = offset; i < data.len(); i++) {
            LRC = (LRC + data[i]) & 0xFF;
        }
        return ((LRC ^ 0xFF) + 1) & 0xFF;
    }

    static function _serialize (b, obj) {
        switch (typeof obj) {
            case "integer":
                return _write(b, 'i', format("%d", obj));
            case "float":
                // 'F' is for new floats, 'f' is for legacy floats
                local bl = blob(4);
                bl.writen(obj, 'f');
                return _write(b, 'F', bl);
            case "null":
            case "function": // Silently setting this to null
                return _write(b, 'n');
            case "bool":
                return _write(b, 'b', obj ? "\x01" : "\x00");
            case "blob":
                return _write(b, 'B', obj);
            case "string":
                return _write(b, 's', obj);
            case "table":
                local sorted = array(obj.len());
                local i = 0;
                foreach ( k,v in obj ) {
                    sorted[i++] = [k,v];
                }
                sorted.sort( @( first, second ) first[0] <=> second[0] );
                _write(b, 't', obj.len());
                foreach ( v in sorted ) {
                    _serialize(b, v[0]);
                    _serialize(b, v[1]);
                }
                return;
            case "array":
                _write(b, 'a', obj.len());
                foreach ( k,v in obj ) {
                    _serialize(b, k);
                    _serialize(b, v);
                }
                return;
            default:
                throw ("Can't serialize " + typeof obj);
        }
    }

    static function _write(b, type, payload = null) {
        // Calculate the lengths
        local prefix_length = true;
        local payloadlen = 0;
        switch (type) {
            case 'n':
            case 'b':
                prefix_length = false;
                break;
            case 'a':
            case 't':
                payloadlen = payload;
                break;
            default:
                payloadlen = payload.len();
        }

        // Update the blob
        b.writen(type, 'b');
        if (prefix_length) {
            b.writen(payloadlen >> 8 & 0xFF, 'b');
            b.writen(payloadlen & 0xFF, 'b');
        }
		if (typeof payload == "string" || typeof payload == "blob") {
            if (payload.len() > 0) {
                foreach (ch in payload) {
                    b.writen(ch, 'b');
                }
            }
        }
    }

    static function _deserialize (s, p = 0) {
        for (local i = p; i < s.len(); i++) {
            local t = s[i];

            switch (t) {
                case 'n': // Null
                    return { val = null, len = 1 };
                case 'i': // Integer
                    local len = s[i+1] << 8 | s[i+2];
                    s.seek(i+3);
                    local val = s.readblob(len).tostring().tointeger();
                    return { val = val, len = 3+len };
                case 'F': // New Floats
                    local len = s[i+1] << 8 | s[i+2];
                    s.seek(i+3);
                    local val = s.readblob(len).readn('f');
                    return { val = val, len = 3+len };
                case 'f': // Legacy Float deserialization :(
                    local len = s[i+1] << 8 | s[i+2];
                    s.seek(i+3);
                    local val = s.readblob(len).tostring().tofloat();
                    return { val = val, len = 3+len };
                case 'b': // Bool
                    local val = s[i+1];
                    return { val = (val == 1), len = 2 };
                case 'B': // Blob
                    local len = s[i+1] << 8 | s[i+2];
                    local val = blob(len);
                    for (local j = 0; j < len; j++) {
                        val[j] = s[i+3+j];
                    }
                    return { val = val, len = 3+len };
                case 's': // String
                    local len = s[i+1] << 8 | s[i+2];
                    local val = "";
                    s.seek(i+3);
                    if (len > 0) {
                        val = s.readblob(len).tostring();
                    }
                    return { val = val, len = 3+len };
                case 't': // Table
                case 'a': // Array
                    local len = 0;
                    local nodes = s[i+1] << 8 | s[i+2];
                    i += 3;
                    local tab = null;

                    if (t == 'a') tab = [];
                    if (t == 't') tab = {};

                    for (local node = 0; node < nodes; node++) {

                        local k = _deserialize(s, i);
                        i += k.len;
                        len += k.len;

                        local v = _deserialize(s, i);
                        i += v.len;
                        len += v.len;

                        if (typeof tab == "array") tab.push(v.val);
                        else tab[k.val] <- v.val;
                    }
                    return { val = tab, len = len+3 };
                default:
                    throw format("Unknown type: 0x%02x at %d", t, i);
            }
        }
    }
}