--[[

Simple job_submit plugin that redirects all jobs to the gpu partition if GPUs are requested 

--]]

function slurm_job_submit(job_desc, job_rec, part_list, modify_uid)
	if string.match(job_desc['tres_per_job'],'gpu')  then
		slurm.log_info("slurm_job_modify: job requested partition %s but seems to need GPUs, hence we redirect to partition gpu",
				job_desc.partition)
		job_desc.partition = "gpu"
	end

	return slurm.SUCCESS
end

function slurm_job_modify(job_desc, job_rec, part_list, modify_uid)

   return slurm.SUCCESS
end

slurm.log_info("initialized")
return slurm.SUCCESS

