// go get github.com/ugorji/go/codec
// go run server.go
package main

import (
	"fmt"
	"log"
	"net"
	"net/http"
	"net/rpc"

	"github.com/ugorji/go/codec"
)

// The request structure type
// JSON tags are reused by go-codec for all encoding formats
type HelloWorldRequest struct {
	Name string `json:"name"`
}

// The response structure type
type HelloWorldResponse struct {
	Greeting string `json:"greeting,omitempty"`
	Error    string `json:"error,omitempty"`
}

// Our empty placeholder server type
type HelloWorldServer struct{}

// The request handler. It follows the usual net/rpc requirements.
// Note that the return `error` is akin to a 500 Internal Server Error,
// and shouldn't be used for  errors directed at the consumer.
func (s *HelloWorldServer) HelloWorld(request *HelloWorldRequest, response *HelloWorldResponse) error {
	if request.Name == "" {
		response.Error = "Name is required"
		return nil
	}
	response.Greeting = fmt.Sprintf("Hello, %s", request.Name)
	return nil
}

func main() {
	// Register the service with RPC
	var s HelloWorldServer
	rpc.RegisterName("Greeter", &s)

	go func() {
		// Using custom codecs with net/rpc is verbose, but isolated to this piece of code
		var mh codec.MsgpackHandle
		listener, err := net.Listen("tcp", "127.0.0.1:12345")
		if err != nil {
			log.Fatalf("failed to listen on msgpack-rpc address: %v", err)
		}
		log.Print("Msgpack listening on port 12345, Ctrl+C to abort")
		for {
			conn, err := listener.Accept()
			if err != nil {
				log.Fatalf("failed to accept msgpack-rpc connection: %v", err)
			}
			rpcCodec := codec.MsgpackSpecRpc.ServerCodec(conn, &mh)
			go func() {
				rpc.ServeCodec(rpcCodec)
			}()
		}
	}()

	// HTTP/JSON API for the benchmarking example
	h := new(codec.JsonHandle)
	http.HandleFunc("/hello_world", func(w http.ResponseWriter, r *http.Request) {
		var request HelloWorldRequest
		var response HelloWorldResponse

		dec := codec.NewDecoder(r.Body, h)
		dec.Decode(&request)
		s.HelloWorld(&request, &response)
		w.WriteHeader(http.StatusOK)
		enc := codec.NewEncoder(w, h)
		enc.Encode(response)
	})
	log.Print("HTTP listening on port 12344, Ctrl+C to abort")
	http.ListenAndServe("127.0.0.1:12344", nil)
}
