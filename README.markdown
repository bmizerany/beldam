Licenced under the MIT licences

Patches welcome

### Example:

Get all instances

`EC2::Instance.all`

reloaded:

`EC2::Instance.all(true)`

`instance = EC2::Instance.run("ami-1234")`

`p instance`

`p instance.public_dns`

`p instance.running?`

`instance.destory`

... and more ...
