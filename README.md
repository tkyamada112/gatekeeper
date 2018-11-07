# GateKeeper

## Description
GateKeeper opens `tcp:22` port at AWS Secuirty-Grouup.
If your resources in public subnet, You can coonnection ssh easily using this.

## How to
GateKeeper works based on slack.
When you speak open keyword on any slack-channnel, the security-group's port will be open.
The keywords that react is below.

```
# gate open develop xxx.xxx.xxx.xxx
# gate close develop xxx.xxx.xxx.xxx
```

## Installation

1. Edit config.rb
Set the followings.
 - `SLACK_OUTGOING_TOKEN`
 - `AWS Some Variables`
 - `Operation Allow Users` (means slack's display-name)

2. Hosting this App.(e.g.:Heroku)
