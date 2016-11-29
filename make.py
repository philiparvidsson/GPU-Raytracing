import os, sys
sys.path.insert(0, os.path.join('build', 'pymake2'))

from pymake2 import *
from pymake2.template.csharp import csc

CONF = { 'libdirs': csc.conf.libdirs + [ csc.conf.bindir ],
         'libs'   : csc.conf.libs    + [ 'PrimusGE.dll'  ] }

@default_target
@depends_on('content', 'libs', 'compile')
def all(conf):
    pass

@target(conf=csc.conf)
def content(conf):
    copy(conf.srcdir, conf.bindir, '*.hlsl')
    copy(r'vendor\PrimusGE\assets\Content', os.path.join(conf.bindir, 'Content'))

@target(conf=csc.conf)
def init(conf):
    run_program('git', [ 'submodule', 'init'   ])
    run_program('git', [ 'submodule', 'update' ])

@target(conf=csc.conf)
@depends_on('primusge_compile')
def libs(conf):
    copy(r'vendor\PrimusGE\bin'        , conf.bindir, '*.dll')
    copy(r'vendor\PrimusGE\lib\SharpDX', conf.bindir, '*.dll')

@after_target('clean')
def primusge_clean(conf):
    cwd = os.getcwd()
    os.chdir(r'vendor\PrimusGE')

    run_program('python', [ 'make.py', 'clean' ])

    os.chdir(cwd)

@before_target('compile')
@target(conf=csc.conf)
def primusge_compile(conf):
    cwd = os.getcwd()
    os.chdir(r'vendor\PrimusGE')

    run_program('python', [ 'make.py', 'compile' ])

    os.chdir(cwd)

@target(conf=csc.conf)
@depends_on('all')
def scene0(conf):
    os.chdir(conf.bindir)
    run_program(conf.name, [ 'Scene0.ps.hlsl' ])

@target(conf=csc.conf)
@depends_on('all')
def scene1(conf):
    os.chdir(conf.bindir)
    run_program(conf.name, [ 'Scene1.ps.hlsl' ])

pymake2(CONF)
