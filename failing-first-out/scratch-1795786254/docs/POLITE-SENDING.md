# Polite sending

Every limit on what Wuber sends to other players, in plain sentences, each with its constant, its value and the file that sets it. Times are seconds, sizes are bytes. Nothing here changes behaviour: it only writes down what the code does. The test `tests/polestar/p19_polite_limits_test.lua` reads the tables below and fails if a value or the file no longer sets it from the code, so when you change a limit, change this file in the same commit.

## Strangers and contacts (whispers to people Wuber has not confirmed, or only knows as contacts)

| Limit | Constant | Value | Where |
|---|---|---|---|
| A round of whispered Q asks at most this many names. | `NETK.ROUND_MAX` | 8 | `Wuber/Net/Discovery.lua` |
| Whispered Qs in a round go this many seconds apart. | `NETK.ROUND_STEP` | 1 | `Wuber/Net/Discovery.lua` |
| A round runs at most this often (seconds) while the Wuber window is open. | `NETK.OPEN_EVERY` | 60 | `Wuber/Net/Discovery.lua` |
| ... and this often (seconds) while it is closed. | `NETK.CLOSED_EVERY` | 300 | `Wuber/Net/Discovery.lua` |
| At most one whispered Q to the same driver per this many seconds. | `NETK.Q_GAP` | 45 | `Wuber/Net/Discovery.lua` |
| At most this many whispered Qs in any 60 seconds. | `NETK.Q_CAP` | 16 | `Wuber/Net/Discovery.lua` |
| A driver heard on the channel this recently (seconds) gets no whispered Q. | `NETK.CHANNEL_FRESH` | 90 | `Wuber/Net/Discovery.lua` |
| After "No player named", no Q to that player for this many seconds. | `NETK.OFFLINE_FOR` | 300 | `Wuber/Net/Discovery.lua` |
| ... for a founder, this many seconds (a founder is often not logged in). | `NETK.OFFLINE_FOUNDER` | 1800 | `Wuber/Net/Discovery.lua` |
| At most this many known drivers are asked. | `NETK.KNOWN_MAX` | 40 | `Wuber/Net/Discovery.lua` |
| At most this many unconfirmed names are asked to confirm. | `NETK.UNCONFIRMED_MAX` | 60 | `Wuber/Net/Discovery.lua` |
| ... on a founder's client (the hub), this many. | `NETK.UNCONFIRMED_FOUNDER` | 150 | `Wuber/Net/Discovery.lua` |
| An unconfirmed name gets at most this many Qs before it is dropped. | `NETK.UNCONFIRMED_TRIES` | 2 | `Wuber/Net/Discovery.lua` |
| The sender of a "[Wuber]" advert line is asked for this many seconds. | `NETK.ADVERT_FRESH` | 120 | `Wuber/Net/Discovery.lua` |
| A name that says "wuber" in public chat gets one hidden Q per this many seconds. | `NETK.MENTION_GAP` | 3600 | `Wuber/Net/Discovery.lua` |
| ... at most this many such Qs in any hour. | `NETK.MENTION_CAP` | 12 | `Wuber/Net/Discovery.lua` |
| ... at most one per this many seconds. | `NETK.MENTION_STEP` | 10 | `Wuber/Net/Discovery.lua` |
| ... at most this many wait to be sent. | `NETK.MENTION_QUEUE` | 5 | `Wuber/Net/Discovery.lua` |
| ... none in the first this many seconds after login or reload. | `NETK.MENTION_QUIET` | 60 | `Wuber/Net/Discovery.lua` |
| At most this many contacts are kept. | `NETK.PEERS_MAX` | 30 | `Wuber/Net/Discovery.lua` |
| A community member list seeds at most this many whispered asks. | `CX.SEEDS_MAX` | 10 | `Wuber/Net/Community.lua` |
| A gossip K names at most this many drivers. | `NETK.GOSSIP_NAMES` | 8 | `Wuber/Net/Discovery.lua` |
| Only drivers heard directly in the last this many seconds are passed on. | `NETK.GOSSIP_FRESH` | 1800 | `Wuber/Net/Discovery.lua` |
| At most one K to the same contact per this many seconds. | `NETK.GOSSIP_PEER_GAP` | 600 | `Wuber/Net/Discovery.lua` |
| At most this many Ks in any 60 seconds. | `NETK.GOSSIP_CAP` | 6 | `Wuber/Net/Discovery.lua` |
| Fewer live names than this: recently seen ones follow. | `NETK.GOSSIP_LIVE_MIN` | 6 | `Wuber/Net/Discovery.lua` |
| ... at most this many recently seen names follow. | `NETK.GOSSIP_SEEN` | 4 | `Wuber/Net/Discovery.lua` |
| A driver announces itself to a founder at most once per this many seconds. | `NETK.ANNOUNCE_EVERY` | 900 | `Wuber/Net/Discovery.lua` |
| ... to at most this many founders. | `NETK.ANNOUNCE_MAX` | 4 | `Wuber/Net/Discovery.lua` |

## Drivers (what a driver sends, and to whom)

| Limit | Constant | Value | Where |
|---|---|---|---|
| A beacon goes out every this many seconds ... | `NETK.BEACON_EVERY` | 60 | `Wuber/Net/Base.lua` |
| ... plus or minus this many seconds of jitter. | `NETK.BEACON_JITTER` | 10 | `Wuber/Net/Base.lua` |
| A change is beaconed at most once per this many seconds. | `NETK.BEACON_GAP` | 5 | `Wuber/Net/Base.lua` |
| A driver answers at most one Q in this many seconds. | `NETK.Q_QUIET` | 15 | `Wuber/Net/Base.lua` |
| A rider who whispered a Q gets our changes for this many seconds ... | `NETK.RIDER_KEEP` | 330 | `Wuber/Net/Beacons.lua` |
| ... at most this many riders (the latest). | `NETK.PUSH_MAX` | 25 | `Wuber/Net/Beacons.lua` |
| One whispered answer per rider per this many seconds. | `NETK.REPLY_QUIET` | 15 | `Wuber/Net/Beacons.lua` |
| At most this many whispered answers in any 15 seconds at once. | `NETK.REPLY_CAP` | 10 | `Wuber/Net/Beacons.lua` |
| Answers past that cap are staggered, at most this many more. | `NETK.STAGGER_MAX` | 24 | `Wuber/Net/Beacons.lua` |
| A rider who booked with us gets no answers or pushes for this many seconds. | `NETK.BOOKED_FOR` | 600 | `Wuber/Net/Beacons.lua` |

The "wuber" Q above is also shared between a player's own windows (crew, captain, own accounts): together they send one Q per name per hour, an own character is never asked, and the hour is kept over a reload or relog.

## Riders (what a rider sends to a driver or shares)

| Limit | Constant | Value | Where |
|---|---|---|---|
| A rider sends Q at most once per this many seconds. | `NETK.PING_GAP` | 20 | `Wuber/Net/Base.lua` |
| R is sent once more after this many seconds without A or N. | `NETK.RESEND_AFTER` | 8 | `Wuber/Net/Base.lua` |
| A shared flight price goes out at most once per this many seconds. | `NETK.FLY_GAP` | 60 | `Wuber/Net/Flights.lua` |
| At most this many shared flight messages in the cap window. | `NETK.FLY_CAP` | 4 | `Wuber/Net/Flights.lua` |
| Shared flight prices go to at most this many peers. | `NETK.FLY_PEER_MAX` | 10 | `Wuber/Net/Flights.lua` |
| A flight message holds at most this many entries. | `NETK.FLY_ENTRIES` | 6 | `Wuber/Net/Flights.lua` |
| A flight message is at most this many bytes. | `NETK.FLY_BYTES` | 250 | `Wuber/Net/Flights.lua` |
| Incoming flight messages accepted: at most this many in the cap window. | `NETK.FLY_IN_CAP` | 3 | `Wuber/Net/Flights.lua` |
| A flight-price ask names at most this many flights. | `NETK.FLY_WANTS` | 8 | `Wuber/Net/Flights.lua` |
| At most this many flight-price messages wait in the send queue. | `NETK.FLY_QUEUED` | 3 | `Wuber/Net/Transport.lua` |
| At most this many V (raincheck) messages per ride each way. | `RK.PER_RIDE` | 3 | `Wuber/Net/Raincheck.lua` |
| An IOU fact is at most this many bytes. | `RK.IOU_MAX` | 90 | `Wuber/Net/Raincheck.lua` |

## The channel and public chat

| Limit | Constant | Value | Where |
|---|---|---|---|
| A "[Wuber]" advert is posted at most once per this many seconds. | `W.ADVERT_GAP` | 900 | `Wuber/Net/Outreach.lua` |
| An advert line is at most this many bytes. | `NETK.ADVERT_MAX` | 200 | `Wuber/Net/Outreach.lua` |
| A periodic D goes to the community this many seconds after the last copy. | `CX.EVERY` | 80 | `Wuber/Net/Community.lua` |
| A rider's Q copy to the community goes at most this often (seconds). | `CX.Q_GAP` | 60 | `Wuber/Net/Community.lua` |

## Everything that leaves the addon (the shared send budget)

| Limit | Constant | Value | Where |
|---|---|---|---|
| Messages that may go out at once. | `NETK.BURST` | 4 | `Wuber/Net/Base.lua` |
| Messages a second after that. | `NETK.RATE` | 1 | `Wuber/Net/Base.lua` |
| At most this many messages wait in the queue. | `NETK.MAX_QUEUE` | 40 | `Wuber/Net/Base.lua` |
| A message is at most this many bytes. | `NETK.MAX_BYTES` | 255 | `Wuber/Net/Base.lua` |
| At most this many whisper-fallback messages (D, X, Q, K) wait. | `NETK.MAX_LOW` | 12 | `Wuber/Net/Transport.lua` |
| After "can't send", probe again no sooner than this many seconds. | `NETK.CANT_SEND_PROBE` | 300 | `Wuber/Net/Transport.lua` |

Other limits are not listed because the code already states them next to the number: for example the 250-byte addon message rule in AGENTS.md. The tables hold 56 limits.
