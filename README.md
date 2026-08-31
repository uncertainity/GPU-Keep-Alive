# GPUKeepAlive

GPUKeepAlive is a lightweight, filesystem-backed Bash job queue for running local jobs sequentially. It can also keep a GPU occupied by automatically submitting a fallback job whenever the queue is empty.

## Usage

Start the worker:

```bash
./worker.sh
```

Submit any Bash job:

```bash
./submit_job.sh /path/to/job.sh
```

Optionally keep the queue filled with a fallback GPU job:

```bash
./refill.sh /path/to/fallback-job.sh
```

Stop the currently running job:

```bash
./kill.sh
```

Jobs move through `pending`, `running`, `finished`, and `failed`. These runtime directories are created automatically. Set `GPU_KEEPALIVE_STATE_DIR` to store them somewhere outside the project directory.

> Use the keepalive feature only where reserving an otherwise idle GPU is permitted by the server's resource-sharing policy.
