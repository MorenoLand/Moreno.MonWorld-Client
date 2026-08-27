# Client protocol boundary

The game connection uses binary WebSocket messages at `/ws/game`. The first message is an authentication frame containing a short-lived, one-time API ticket and the local `content_id`.

Each frame has a 14-byte little-endian header:

| Offset | Size | Field |
| ---: | ---: | --- |
| 0 | 2 | Magic `0x4D57` |
| 2 | 1 | Version `1` |
| 3 | 1 | Flags |
| 4 | 2 | Message type |
| 6 | 4 | Sequence |
| 10 | 4 | UTF-8 JSON payload length |

Client sequences start at one for authentication and increase for every later frame. The server rejects malformed frames and non-increasing client sequences. Inputs express actions such as a direction or battle choice; accepted positions, battle state, inventory, and other authority remain server-owned.

This is an original MonWorld protocol. Other projects and reverse-engineering material are behavioral references only.
