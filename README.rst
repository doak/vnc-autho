Introduction
------------

This bunch of scripts enables not-IT-aware people (noobs) to get remote support using only free (*free* like in *freedom*) SW.
It supports both Linux and Windows. For Windows currently pre-compiled Cygwin and TightVNC binaries are used.

Features:
    * Automatic connection between VNC viewer and server. Everything is closed/cleaned-up if *vnc-autho* has been shut down.
    * Configuration can be bundled and is self-hosted: Unzip, execute, run.
    * Connection is end-to-end encrypted using *OpenSSH*.
    * Bidirectional authentication using SSH keys. All keys will be generated dedicated for *vnc-autho*.
    * Support to establish SSH tunnel using a "third-party" SSH server if no one's computer is accessible directly.
      The whole communication is end-to-end encrypted nevertheless!
    * Creation of bundle (packages) is supported by scripts.
    * No need for root/administration rights. The only exception is listen mode on Windows.
    * Remote user is able to adapt configuration easily interactively (using readline).


Prerequisites
-------------

Linux:
    * Usual Linux environment including the following:
        * *xtightvncviewer* or *xtigervncviewer* installed (needed to view other screens).
        * *x11vnc* installed (needed to share your screen).
        * *OpenSSH* installed to connect to a remote host or listen for incoming connections.

Windows:
    * All needed tools are included in the bundle as binaries (parts of *Cygwin* and *TigerVNC*).
    * If listen mode shall be used, the ``sshd`` binary needs a Windows user 'sshd' to exist. Open 'Computer Management|System Tools|Local Users and Groups|Users' to create the new user.  Please also tick the checkbox 'Account is disabled'.


Set-up
------

#) Use script ``./bin/check-setup.sh`` to set-up needed configuration. It will guide you through the configuration.
#) Ensure that ``./etc/host.conf`` is configured completely:
    * ``SSH_USER`` has to be set to your username.
    * ``SSH_HOST`` has to be set to the *external* IP/DNS of your computer.
    * ``SSH_PORT`` has to be set to an unbound port which is accessible from extern.
    * There are several more environment variables which can be used to influence configuration. The most important ones are ``RPORT`` and ``LPORT`` which can be used to configure "asymetric" port forwarding which is needed to test the connection locally.
#) Use script ``./bin/package.sh`` to create an archive which you can share. This will **not** include your SSH host key to ensure that nobody else could impersonate you.
   This script does currently not work in the included Cygwin environment.

Refer to ``./start-vnc-SERVER.sh --help`` (or any other variant) for help.


Example Usage
-------------

How to try out this piece of cake locally ("A first roundtrip"):
    #) Execute ``./bin/check-setup.sh``. Answer all questions with ``y``.
    #) Execute ``./start-vnc-LISTEN.sh``. (Windows user 'sshd' has to exist, see above.)
    #) Execute ``./start-vnc-SERVER.sh``. Enter ``localhost::3333::4444`` for the host and press Return.
    #) Enter your choosen passphrase and press Return.
    #) *Connection will be established.*

View other screen:
    #) Ensure ``etc/host.conf`` has been configured properly. This ensures the remote use do not need to adapt anything.
    #) Provide bundle to remote user.
    #) On you computer: Execute ``./start-vnc-LISTEN.sh`` respectively ``./start-vnc-LISTEN.bat``.
    #) On the remote computer:
        #) Let ``./start-vnc-SERVER.sh`` respectively ``./start-vnc-SERVER.bat`` be executed.
        #) Let remote use accept suggested connection parameters (based on ``./etc/host.conf``).
        #) Provide remote user the passphrase for the SSH client key.
    #) *Connection will be established.*

Share your screen:
    * Same as above, but let the remote user execute the ``VIEWER`` (instead of ``SERVER``) script.

Ensure that your screen will **not** be shared:
    * Just execute ``./start-vnc-VIEWER.sh --listen`` instead of ``./start-vnc-LISTEN.sh``.

Use a remote SSH server as a gateway:
    * Execute both, viewer and server, with the argument ``--ssh-gw <hostspec>``. Both users need permissions to forward ports using their SSH account.
    * The gateway can be configured statically with ``arg_ssh_gw=<hostspec>`` in ``./etc/host.conf`` if needed.
