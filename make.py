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

pymake2(CONF)
