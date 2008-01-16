// Memcached client on ActionScript 3
// Tasuku SUENAGA a.k.a. gunyarakun(not gunyaraway)
// BSD License or meshi-ogoru license

package {
  import flash.display.*;
  import flash.net.*;
  import flash.external.*;
  import flash.events.*;
  import flash.system.*;
  import flash.text.*;

  public class MemcachedClient extends Sprite {
    private var socket:Socket;
    private var js_on_connect:String, js_on_close:String, js_on_get:String, js_on_error:String;
    private var label:TextField;
    private var recv_mode:String;
    private var recv_buf:String;

    public function MemcachedClient() {
      make_label();
      set_label('initialize instance');
      if (ExternalInterface.available) {
        try {
          Security.allowDomain('*');
          ExternalInterface.addCallback('connect', connect);
          ExternalInterface.addCallback('close', close);
          ExternalInterface.addCallback('set', set);
          ExternalInterface.addCallback('get', get);
        } catch (e:SecurityError) {
          set_label('security error: ' + e);
        } catch (e:Error) {
          set_label('other error: ' + e);
        }
      }
      recv_buf = '';
    }

    // connect
    public function connect(host:String, port:int,
                            onconnect:String, onclose:String,
                            onget:String, onerror:String):void {
      socket = new Socket(host, port);
      js_on_connect = onconnect;
      js_on_close = onclose;
      js_on_get = onget;
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
    public function set(key:String, value:String, exptime:uint = 0, flags:uint = 0):void {
      this.send_storage_cmd('set', key, flags, exptime, value);
    }
    // get
    public function get(data:String):void {
      socket.writeUTFBytes(data);
      socket.flush();
    }

    // * for internal use */
    // FIXME: cas_unique:Number
    private function send_storage_cmd(command_name:String, key:String, flags:uint,
                                      exptime:uint, bytes:String) {
      var command = new Array(command_name, key, flags, exptime, bytes.length).join(' ');
      recv_mode = 'storage';
      send_line(command);
      send_line(bytes);
    }

    private function send_retrieval_cmd(command_name:String, key:String) {
      var command = new Array(command_name, key).join(' ');
      recv_mode = 'retrieval';
      send_line(command);
    }

    private function send_line(data:String) {
      if (!socket || !socket.connected) return;
      socket.writeUTFBytes(data);
      socket.writeUTFBytes('\r\n');
      socket.flush();
    }

    private function on_line(line) {
      switch(recv_mode) {
        case 'storage':
          switch(line) {
            case 'STORED':
            case 'NOT_STORED':
            case 'EXISTS':
            case 'NOT_FOUND':
            default:
              set_label(line);
          }
        case 'retrieval':
          // TODO:
        case 'deletion':
          // TODO:
        case 'inc/dec':
          // TODO:
        case 'stats':
          // TODO:
      }
    }

    // * event handlers *
    // connect event
    private function on_connect(evt:Event):void {
      ExternalInterface.call(js_on_connect);
    }
    // close event
    private function on_close(evt:Event):void {
      ExternalInterface.call(js_on_close);
    }
    // data event
    private function on_data(evt:Event):void {
      recv_buf += socket.readUTFBytes(socket.bytesAvailable);
      var e;
      while ((e = recv_buf.indexOf('\n')) != -1) {
        var line = recv_buf.substring(0, e);
        if (on_line(line)) {
          recv_buf = recv_buf.substring(e + 1);
        }
      }
    }
    // handle I/O error
    private function on_io_error(evt:IOErrorEvent):void {
      ExternalInterface.call(js_on_error, evt.text);
      // trace("I/O error !!! " + evt.text);
    }
    // handle security error
    private function on_security_error(evt:SecurityErrorEvent):void {
      ExternalInterface.call(js_on_error, evt.text);
      // trace("security error !!! " + evt.text);
    }

    // * show error message *
    private function make_label():void {
      label = new TextField();
      label.autoSize = TextFieldAutoSize.LEFT;
      label.selectable = true;
      label.text = '';
      label.x = 0;
      label.y = 0;
      addChild(label);
    }
    private function set_label(text:String):void {
      label.text = text;
    }
  }
}
