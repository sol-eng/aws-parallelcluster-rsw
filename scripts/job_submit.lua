--[[

Simple job_submit plugin that redirects all jobs to the gpu partition if a non-zero amount of GPUs are requested 

--]]

function slurm_job_submit(job_desc, job_rec, part_list, modify_uid)
	if ( string.match(job_desc['tres_per_job'],'gpu') and not string.match(job_desc['tres_per_job'],'gpu.*:0') ) then
			job_desc.partition = "gpu"
	end

	return slurm.SUCCESS
end

function slurm_job_modify(job_desc, job_rec, part_list, modify_uid)

   return slurm.SUCCESS
end

slurm.log_info("SLURM job submit plugin initialized")
return slurm.SUCCESS

