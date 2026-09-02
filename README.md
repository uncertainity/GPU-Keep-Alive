# GPUKeepAlive

GPUKeepAlive is a lightweight, filesystem-backed Bash job queue. It runs jobs concurrently when their requested GPUs do not overlap and can keep a fallback GPU job waiting whenever the pending queue is empty.

## Usage

Start the worker with the GPUs it is allowed to manage:

```bash
GPU_KEEPALIVE_GPUS=0,1 ./worker.sh
```

Submit jobs with their requested GPU IDs:

```bash
./submit_job.sh --gpus 0 /path/to/job.sh
./submit_job.sh --gpus 1 /path/to/another_job.sh
./submit_job.sh --gpus 0,1 /path/to/multi_gpu_job.sh
```

Jobs requesting GPU 0 and GPU 1 separately can run at the same time. A job waits in `pending` while any of its requested GPUs are occupied.

## Fallback job

Run the refiller to submit one fallback job whenever `pending` contains no jobs:

```bash
GPU_KEEPALIVE_GPUS=0,1 ./refill.sh /path/to/fallback-job.sh
```

By default, the fallback job requests every GPU in `GPU_KEEPALIVE_GPUS`. Override that GPU list with `GPU_KEEPALIVE_FALLBACK_GPUS`:

```bash
GPU_KEEPALIVE_GPUS=0,1 \
GPU_KEEPALIVE_FALLBACK_GPUS=1 \
./refill.sh /path/to/fallback-job.sh
```

The refiller checks only the pending queue, so it may enqueue the fallback while normal jobs are still running. It submits one fallback job for the configured GPU set, not one fallback per idle GPU.

## Managing jobs

Stop the only running job, or select a job when several are active:

```bash
./kill.sh
./kill.sh <job-id>
```

Jobs move through `pending`, `running`, `finished`, and `failed`. These runtime directories are created automatically. Set `GPU_KEEPALIVE_STATE_DIR` to store them somewhere outside the project directory.

> Use the keepalive feature only where reserving an otherwise idle GPU is permitted by the server's resource-sharing policy.
