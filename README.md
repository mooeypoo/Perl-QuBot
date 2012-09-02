# Perl QuBot #

Perl IRC Bot with Quotes Database by Moriel Schottlender.
mooeypoo@gmail.com

### This bot is now in testing. ###

This is a project I've been working on to get my feet wet in perl.
Feel free to use this bot for your personal uses, but please don't remove the credit.
If you have ideas on how to improve this small bot, post them in the "issues" tab. If you find any bugs or malfunctions, please post them in the "issues".

# Installation #
This bot comes with a perl installer. Run the "qubot.pl" script, and it will automatically launch the installer for you.

# Commands #
The bot is meant mainly as a quote bot; insert a bot into the database and spit out a random one on request. However, there are several extra commands for administration and channel moderation purposes.
## General Commands ##
These are commands anyone in the channel can activate without the need for bot access.
* login [username] [password] - login to the bot (make sure you do this in private message)
* currops - announces what operators and admins are currently logged into the bot
* slap [nickname] - 'slap' someone on the channel.
(more coming up)

## Quote Commands ##
* quote ([id]) - display a quote. If given ID number, it will display that specific quote. Otherwise, it will display a random quote.
* addquote [text] - adds a quote to the database. Can only be done by users with "Contributor" level.
* delquote [id] - deletes a quote from the database. Can only be done by users with "Bot Operator" level.
* infoquote [id] - show more information about specific quote.
* vote [up|down] [quoteID] - increase or decrease the ratings of a quote.

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

