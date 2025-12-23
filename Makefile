.DEFAULT_GOAL := lint
# .SILENT:

STYLUA_OPS		?=	--check .
LUACHECK_OPTS	?=	.

ifneq ($(CI),)
LUACHECK_OPTS	=	--formatter=JUnit . > luacheck-report.xml
endif

stylua:
	stylua $(STYLUA_OPS)

luacheck:
	luacheck $(LUACHECK_OPTS)

lint: stylua luacheck
