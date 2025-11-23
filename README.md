# App

This is a WIP sample app demonstrating how to initiate ID card authentication using the [Web eID](https://github.com/web-eid/web-eid.js) javascript library
and integrating with the [Web eID security](https://github.com/web-eid/web-eid-authtoken-validation-java#quickstart) java library for token validation.

A minimal java application that can be run as a regular os process and invoked from elixir via ports can be found in the `./java_auth_program` directory.

A configurable microservice/sidecar is being worked on for this project and can be found in github [Estonian eID Auth & Signing sidecar WIP](https://github.com/KasparKipp/estonian-eid-auth-signing-sidecar-WIP)

# Getting Started

Before you begin, make sure your computer is properly set up to use your ID card electronically.  
Follow the official guide: [You wish to start using your ID-card electronically](https://www.id.ee/en/article/you-wish-to-start-using-your-id-card-electronically/).


## Prerequisites

Before running the project, ensure you have the following installed on your machine:

- [Elixir & Erlang](https://elixir-lang.org/install.html)
- [Bun](https://bun.com)
- [Java 25]()

## To start your Phoenix server:

* Run `mix setup` to install and setup elixir dependencies
* To run the ports example:
    * Run `./java_auth_program/gradlew -p java_auth_program fatJar` to build the java program that provides authorized credentials communicating via ports.
    * move the jar file `mv ./java_auth_program/build/libs/java-auth-program-0.0.1-SNAPSHOT.jar /usr/local/lib/jauth.jar`
    * make a bash script to `/usr/local/bin/jauth` make the jar accessible to the phx app with jauth command:
    ```bash
    #!/bin/bash
    java -jar /usr/local/lib/jauth.jar "$@"
    ```
    * make the script executable `chmod +x /usr/local/bin/jauth`
* To run the sidecar example:
    * Clone and run [Estonian eID Auth & Signing sidecar WIP](https://github.com/KasparKipp/estonian-eid-auth-signing-sidecar-WIP)
* To run the jinterface example:
    * In development
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix`

Now you can visit [`https://localhost:4001`](https://localhost:4001) from your browser.
> Note: HTTPS is required to communicate with the Web eID browser extension


---------

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
