# Perl QuBot #

Perl IRC Bot with Quotes Database by Moriel Schottlender.
mooeypoo@gmail.com

### This bot is still under development. It's not operational. ###
It's a project I'm working on mainly to practice perl and produce a small useful IRC bot for quotes for channels I chat in. Be patient.



# Commands #
The bot is meant mainly as a quote bot; insert a bot into the database and spit out a random one on request. However, there are several extra commands for administration and channel moderation purposes.
## General Commands ##
These are commands anyone in the channel can activate without the need for bot access.
* slap [nickname] - 'slap' someone on the channel.
(more coming up)
* login [username] [password] - login to the bot (make sure you do this in private message)
* currops - announces what operators and admins are currently logged into the bot
## Bot Operators ##
Operators are allowed to change basic configuration for the bot and users.
* adduser [username] [password] [access_level] [email(optional)] - adds a user to the bot
* edituser [username] [pass:newpass] [username:newuser] [email:new@email.com] - changes details for an existing user
* op [nickname] - op someone in the channel. Only works if the bot is op.

## Bot Administration ##
Bot admin has access to core files. 
* refresh - re-reads configuration files.

# FAQ #
These are potential problems and frequently asked questions. If you ran into a bug or an issue that is not addressed in this list, please open a new issue or email mooeypo@gmail.com

## I forgot my password / lost access to admin! ##
=======
If you lose access to the bot, add this into the users.yml file:

```
---
admin:
  access_level: '9999'
  pass: $1$nlUjcBiL$2laUQnoTTXutoDtnPCt5e1
  username: admin
```
The above record will allow you access with username "admin" and password "admin" as a temporary measure. You can then add, remove and edit users. Don't forget to delete this user from the bot after you create your new administrator!

