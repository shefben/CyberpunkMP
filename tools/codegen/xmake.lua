rule("codegen")
    set_extensions(".proto")

    on_load(function(target)
        -- No dependency on NetPack target since we use pre-built NetPack.exe
    end)

    on_config(function(target)
        local sourcebatch = target:sourcebatches()["codegen"]

        for _, sourcefile in ipairs(sourcebatch.sourcefiles) do
            local outputSourceFile = path.join(target:autogendir(), "rules", "netpack", path.basename(sourcefile) .. ".gen.cpp")
            local objectfile = target:objectfile(outputSourceFile)
            table.insert(target:objectfiles(), objectfile)
        end

        target:add("includedirs", path.join(target:autogendir(), "rules", "netpack"), {public = true})
    end)

    before_buildcmd_file(function(target, batchcmds, sourcefile, opt)
        import("core.project.project")
		import("core.tool.toolchain")

        -- Use NetPack.exe from root directory instead of built target
        local netpack = path.join(os.projectdir(), "NetPack.exe")
        if not os.isfile(netpack) then
            raise("NetPack.exe not found in root directory: " .. netpack)
        end

        local output_dir = path.join(target:autogendir(), "rules", "netpack")
        target:add("includedirs", output_dir, {public = true})

        -- Process common.proto first if it exists and hasn't been processed
        local common_proto = path.join(path.directory(sourcefile), "common.proto")
        local common_header = path.join(output_dir, "common.gen.h")
        if os.isfile(common_proto) and not os.isfile(common_header) and path.basename(sourcefile) ~= "common.proto" then
            batchcmds:show_progress(opt.progress, "${color.build.object}compiling.netpack %s", common_proto)
            local common_argv = {common_proto, output_dir}
            batchcmds:vexecv(netpack, common_argv, { curdir = "." })
        end

        -- add commands for current file
		batchcmds:show_progress(opt.progress, "${color.build.object}compiling.netpack %s", sourcefile)
        local argv = {}

        table.insert(argv, sourcefile)
        table.insert(argv, output_dir)

        batchcmds:vexecv(netpack, argv, { curdir = "." })

		local outputHeaderFile = path.join(target:autogendir(), "rules", "netpack", path.basename(sourcefile) .. ".gen.h")
        local outputSourceFile = path.join(target:autogendir(), "rules", "netpack", path.basename(sourcefile) .. ".gen.cpp")

        local objectfile = target:objectfile(outputSourceFile)
        --table.insert(target:objectfiles(), objectfile)
        batchcmds:compile(outputSourceFile, objectfile)

		-- add deps
		batchcmds:add_depfiles(sourcefile)
		if os.isfile(common_proto) and path.basename(sourcefile) ~= "common.proto" then
		    batchcmds:add_depfiles(common_proto)
		end
		batchcmds:set_depmtime(os.mtime(outputHeaderFile))
		batchcmds:set_depcache(target:dependfile(outputHeaderFile))
        batchcmds:set_depcache(target:dependfile(outputSourceFile))
    end)