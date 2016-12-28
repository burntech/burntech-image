# burntech-image
pre-configured standard burntech server

What is this image?

  This is the "default" BurnTech Raspberry Pi 3 server, and will
  provide:

    - base image is 2016-11-25-raspbian-jessie-lite.zip

    - default copy of Mosquitto (MQTT broker) up and running
    - default copy of nginx (HTTP server) up and running
    - sshd enabled
    - carnival server up and running (port 5061)
    - git-core installed
    - configured as a wireless access point running NAT addressing
    - updated and upgraded through Dec 21, 2016

    - burntech_config.pl, a configuration script that will set up your router

    (see changesToPi for a more comprehensive list of things done to the stock image)

NOTE:  This image is 550MB compressed, and is available on the Google Drive.  I'm
pretty sure posting the Google Drive location here would make it accesible to 
planet Earth, so we're not doing that.


