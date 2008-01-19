// Memcached client on ActionScript3
// Tasuku SUENAGA a.k.a. gunyarakun(not gunyaraway)
// BSD License or meshi-ogoru license

// はらへった。

package {
  import flash.display.Sprite
  import flash.net.Socket
  import flash.external.ExternalInterface
  import flash.events.*;
  import flash.system.*;
  import flash.utils.ByteArray;

  public class MemcachedClient extends Sprite {
    private var socket:Socket;
    private var js_on_connect:String, js_on_close:String,
                js_on_response:String, js_on_error:String;
    private var recv_buf:String;
    private var recv_info:Object;

    public function MemcachedClient() {
      if (ExternalInterface.available) {
        try {
          Security.allowDomain('*');
          ExternalInterface.addCallback('connect', connect);
          ExternalInterface.addCallback('close', close);
          ExternalInterface.addCallback('set', set);
          ExternalInterface.addCallback('get', get);
        } catch (e:SecurityError) {
          trace('security error: ' + e);
        } catch (e:Error) {
          trace('other error: ' + e);
        }
      }
      recv_buf = '';
    }

    // connect
    public function connect(host:String, port:int,
                            onconnect:String, onclose:String,
                            onresponse:String, onerror:String):void {
      socket = new Socket(host, port);
      js_on_connect = onconnect;
      js_on_close = onclose;
      js_on_response = onresponse;
      js_on_error = onerror;
      socket.addEventListener(Event.CLOSE, on_close);
      socket.addEventListener(ProgressEvent.SOCKET_DATA, on_data);
      socket.addEventListener(Event.CONNECT, on_connect);
      socket.addEventListener(IOErrorEvent.IO_ERROR, on_io_error);
      socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, on_security_error);
    }
    // close
    public function close():void {
      if (!socket || !socket.connected) return;
      socket.close();
    }
    // set
    // TODO: prepend invalid key/value
    public function set(key:String, value:String, exptime:uint = 0,
                        flags:uint = 0):void {
      send_storage_cmd('set', key, flags, exptime, value);
    }
    // get
    public function get(keys:Array):void {
      send_retrieval_cmd('get', keys);
    }

    // * for internal use */
    // FIXME: cas_unique:Number
    public function send_storage_cmd(command_name:String, key:String,
                                     flags:uint,
                                     exptime:uint, bytes:String):void {
      var b:ByteArray = new ByteArray();
      b.writeUTFBytes(bytes);
      var command:String = new Array(command_name, key, flags, exptime, b.length).join(' ');
      recv_info = {'command': command_name,
                   'key': key,
                   'flags': flags,
                   'exptime': exptime,
                   'bytes': bytes
                  };
      send_line(command);
      send_line(bytes);
    }

    public function send_retrieval_cmd(command_name:String, keys:Array):void {
      recv_info = {'command': command_name,
                   'keys': keys
                  };
      var command:String = command_name + ' ' + keys.join(' ');
      send_line(command);
    }

    public function send_line(data:String):void {
      if (!socket || !socket.connected) return;
      socket.writeUTFBytes(data);
      socket.writeUTFBytes('\r\n');
      socket.flush();
    }

    // return lines handled
    // TODO: error handling
    public function on_lines(lines:Array):uint {
      if (lines.length < 2) { return 0; }
      switch(recv_info.command) {
        case 'set':
          ExternalInterface.call(js_on_response, recv_info, lines[0]);
          return 1;
        case 'get':
          if (lines[0] == 'END') {
            return 1;
          } else if (lines.length < 2) {
            // not yet
            return 0;
          }
          var rh:Array = lines[0].split(' ');
          // TODO: check rh[0] == 'VALUE'
          // length check
          var i:uint = 0;
          var value:String = '';
          var len:uint = 0;
          for (i = 1; i < lines.length; i++) {
            var b:ByteArray  = new ByteArray();
            b.writeUTFBytes(lines[i]);
            len += b.length + 2; // \r\n
            value += lines[i] + '\r\n';
            if (len >= rh[3]) {
              break;
            }
          }
          if (len < rh[3]) {
            return 0; // not received enough data
          }
          var ret:Object = {'key': rh[1],
                            'flags': rh[2],
                            'bytes': len,
                            'value': value
                           };
          if (rh.length == 5) {
            ret['cas_unique'] = rh[4];
          }
          ExternalInterface.call(js_on_response, recv_info, ret);
          return i + 1;
      }
      return 1;
    }

    // * event handlers *
    // connect event
    public function on_connect(evt:Event):void {
      ExternalInterface.call(js_on_connect);
    }
    // close event
    public function on_close(evt:Event):void {
      ExternalInterface.call(js_on_close);
    }
    // data event
    public function on_data(evt:Event):void {
      recv_buf += socket.readUTFBytes(socket.bytesAvailable);
      var lines:Array = recv_buf.split('\r\n');
      while (true) {
        var c:uint = on_lines(lines);
        if (c > 0) {
          for (var i:uint = 0; i < c; i++) {
            lines.shift();
          }
        } else {
          recv_buf = lines.join('\r\n');
          break;
        }
      }
    }
    // handle I/O error
    public function on_io_error(evt:IOErrorEvent):void {
      ExternalInterface.call(js_on_error, evt.text);
      // trace("I/O error !!! " + evt.text);
    }
    // handle security error
    public function on_security_error(evt:SecurityErrorEvent):void {
      ExternalInterface.call(js_on_error, evt.text);
      // trace("security error !!! " + evt.text);
    }
  }
}
