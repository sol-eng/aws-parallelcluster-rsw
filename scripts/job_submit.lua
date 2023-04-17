--[[

 Example lua script demonstrating the Slurm job_submit/lua interface.
 This is only an example, not meant for use in its current form.

 For use, this script should be copied into a file name "job_submit.lua"
 in the same directory as the Slurm configuration file, slurm.conf.

--]]

function slurm_job_submit(job_desc, job_rec, part_list, modify_uid)
	if job_desc.partitions == "all" then
		slurm.log_info("slurm_job_modify: for job %u from uid %u, setting default comment value: %s",
				job_rec.job_id, modify_uid, comment)
		job_desc.partition = "gpu"
	end

	return slurm.SUCCESS
end

function slurm_job_modify(job_desc, job_rec, part_list, modify_uid)
   return slurm.SUCCESS
end

slurm.log_info("initialized")
return slurm.SUCCESS

