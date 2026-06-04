# ==================================================================================
# SolidgroundUX - General documentation
# ----------------------------------------------------------------------------------
# Metadata:
#   Version     : 1.5
#   Build       : 2615600
#   Checksum    : -
#   Source      : solidgroundux_preface.sh
#   Type        : documentation
#   Group       : -
#   Purpose     : Product preface
#
# Attribution:
#   Developers  : Mark Fieten
#   Company     : Testadura Consultancy
#   Client      : -
#   Copyright   : © 2025 Mark Fieten — Testadura Consultancy
#   License     : Licensed under the Testadura Non-Commercial License (TD-NC) v1.0.
# ==================================================================================

# - Raison d'être -------------------------------------------------------------------
# > During a period in which I found myself lacking mental callenges in my current project, I decided to explore
# > the Linux world. Frustrated about current software market I envisionedc omming up with a subscription free, vendor-neutral, on-site 
# > software solution. This started with configuring some vm's, which quickly lead to needing to learn some bash. Got a lot of help
# > with syntax from ChartGPT, but aalready concluded that I didn;t want to have to type say() printf.... etc. every time I wanted  to convey something
# > to the user or needed some input. Coming from the C# .Net ecosystem took some adjustment, especially not thinking OOP anymore, but
# > always trying to find ways to make things more modular and reusable. To make a long story short, 6 months hende, I present to you
# > SolidgroundUX, a modular, reusable, consistent, and hopefully enjoyable to use framework for building console applications in bash. Not bad for a
# > first bash project, haven't configured a single vm since I started, wonder if it works.... 
# > I'm releasing this software on GitHub under the Testadura Non-Commercial License (TD-NC) v1.0, which means you can use it for free for non-commercial purposes even
# > in a commercial settiing. However, if you want to use it in a commercial project, we will need to discuss terms.
# > I hope this makes someone's life easier, and if you have any suggestions for improvements or want to contribute, feel free to reach out.
# 
# -- What's in a name? ----------------------------------------------------------------
# > The name Solidground is the name of a .Net ETL orchestration framework I developed in the past 10 years. The product iss currently awaiting adaptation
# > to the Linux world, and the Avalonia UI framork and will be releeased as a commercial product in the, hopefully, ear future. The name SolidgroundUX is a nod to that product.
#
# - SolidgroundUX in a nutshell -------------------------------------------------------
# > SolidgroundUX is a collection of bash libraries and tools to make it easier to build console applicaations in bash. It contains a set of functions and common variables
# > to provide for the boiler plate code needed to deal with commandline arguments, cfg-files, state-variables, and some Ui like components. The core of the framwework
# > consists of a classic bootstrapper architecture. The libraries sgnd-bootstrap.sh and sgnd-bootstrap-env.sh provide a bootstrapping mechanisms that can optionally be used
# > in scripts and libraries to enabled command line arguments, automatic loading oof necessary libraries andin any case initiates some global variables dealing with expected file locations.
# > To write your own scripts using the framework, there are script templates available. These contain the minimum needed boilerplate to get you started. There are templates 
# > for executable and library scripts. There's  an additional template for modules, which can be serviced by a modular console application, providing unified menu.
# > The framework also provides aset of tools to create VSCode workspaces, deploy workspaces, create packages, edit metadata, and generate documentation. The documentation
# > generator does exactly that, it obtains documentation from the source files. the template doc-sample.sh contaans a demonstration of the documentation conventions. De  documentation
# > is generated in html format so it can be read by any browser. It currently onlyu suppports bash scripts, but is fully poised to support python and C# in the future.

