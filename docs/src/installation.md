# [Installation](@id Installation)

## Install Julia

Cropbox is a domain-specific language (DSL) for [Julia](https://julialang.org). To use Cropbox, you must first [download and install](https://julialang.org/downloads/) Julia. For new users, it is recommended to install the "Current stable release" for Julia. In general, you will want to install the 64-bit version. If you run into an issue, you can try the 32-bit version.

While you can technically use the terminal or command prompt to run your code, 

## Install Cropbox

[Cropbox.jl](https://github.com/cropbox/Cropbox.jl) is available through Julia package manager.

```julia
using Pkg
Pkg.add("Cropbox")
```

## Docker

If you would like to skip the process of installing Julia and Cropbox on your machine...

There is a [Docker image](https://hub.docker.com/repository/docker/cropbox/cropbox) with Cropbox precompiled for convenience. By default, Jupyter Lab will be launched.

```shell
$ docker run -it --rm -p 8888:8888 cropbox/cropbox
```

If REPL is preferred, you can directly launch an instance of Julia session.

```shell
$ docker run -it --rm cropbox/cropbox julia
               _
   _       _ _(_)_     |  Documentation: https://docs.julialang.org
  (_)     | (_) (_)    |
   _ _   _| |_  __ _   |  Type "?" for help, "]?" for Pkg help.
  | | | | | | |/ _` |  |
  | | |_| | | | (_| |  |  Version 1.6.1 (2021-04-23)
 _/ |\__'_|_|_|\__'_|  |  Official https://julialang.org/ release
|__/                   |

julia>
```

## Binder

The docker image can be also launched via Binder without installing anything locally.

[![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/cropbox/cropbox-binder/main)