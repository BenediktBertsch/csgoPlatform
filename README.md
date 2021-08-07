# CS:GO Platform
Replaces ChallengeMe (which went down...) with the option to selfhost.
CSGO Platform has been created to create dynamically multiple simultaneous 1vs1 battles among friends. The program exposes an API where you can request following things:
- /create -> creates a single CS:GO 1vs1 server with a randomized map of the collection
- /create?id=XXXXXXX -> creates the server with a specific map
- /maps -> lists all maps with their name, id and preview picture

## How to use
Following environment variables are necessary to get the application running:
- GSLTS ([Where do I create the Game Server Login Tokens](https://steamcommunity.com/dev/managegameservers))
- AUTHKEY ([How to obtain the key](https://steamcommunity.com/dev/apikey))

Optional:

- WS_COLLECTION (Mappool, default is mine: 1809672996 - [More information](https://developer.valvesoftware.com/wiki/CSGO_Workshop_For_Server_Operators))

- PORTSTART (sets the start number for ex. 27016 and counts up to the many servers you have)

To get statistics working (You need a MySQL Server):
- db_Host
- db_Name
- db_User
- db_Password
- db_Port (predefined 3306)

## WIP
There are still alot of things todo:

CS:GO Plugin:
- rework the plugin to save more and better stats (headshots, kills, map, ...)
- shutdown the server if there is only one or no one connected in the first 5 minutes (better resource management)

Future:
- Create surf, training and more types of server, not only 1vs1
- Save the demo of the match (optional)
- Possible FrontEnd with Steam OAuth integration
- Discord Bot to challenge your friends fast and easy ([in the works](https://github.com/yannickfunk/1v1Discord))