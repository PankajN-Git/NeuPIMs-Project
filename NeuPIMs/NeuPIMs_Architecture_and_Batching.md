# NeuPIMs Project: End-to-End Flow, Batching, Sub-Batching, and MHA

## 1. Project overview

NeuPIMs is a cycle-level simulator for heterogeneous neural-network inference using:

- NPU resources, such as systolic arrays and vector units
- Processing-in-memory (PIM) resources
- DRAM and memory channels
- Transformer/LLM model operations
- Request traces containing individual inference requests

The simulator estimates execution time, request latency, memory traffic, and PIM/DRAM power or energy behavior.

The default experiment runner is [`brun.sh`](./brun.sh). It connects the selected hardware, memory, model, system, and request-trace configurations to the simulator executable.

Important project areas include:

| Area | Purpose |
|---|---|
| [`src/`](./src/) | Main simulator implementation |
| [`configs/`](./configs/) | Hardware, memory, model, and system configurations |
| [`request-traces/`](./request-traces/) | CSV traces containing individual requests |
| [`trace-generator/`](./trace-generator/) | Generates request traces from token-length distributions |
| [`extern/NewtonSim/`](./extern/NewtonSim/) | DRAM/PIM timing and power modeling |
| [`brun.sh`](./brun.sh) | Experiment launcher |

Typical default configuration files include:

- [`configs/systolic_ws_128x128_dev.json`](./configs/systolic_ws_128x128_dev.json)
- [`configs/memory_configs/neupims.json`](./configs/memory_configs/neupims.json)
- [`configs/model_configs/gpt3-7B.json`](./configs/model_configs/gpt3-7B.json)
- [`configs/system_configs/sub-batch-off.json`](./configs/system_configs/sub-batch-off.json)
- [`request-traces/clb/share-gpt2-bs512-ms7B-tp4-clb-0.csv`](./request-traces/clb/share-gpt2-bs512-ms7B-tp4-clb-0.csv)

---

## 2. End-to-end execution flow

The overall flow is:

```text
Dataset/token statistics
          |
          v
Trace generator
          |
          v
CSV request trace
          |
          v
RequestGenerator
          |
          v
Client/request queues
          |
          v
Scheduler and active requests
          |
          v
Model operations and tiles
          |
          +--------------------+
          |                    |
          v                    v
        NPU                 PIM/DRAM
          |                    |
          +---------+----------+
                    |
                    v
              Cycle simulation
                    |
                    v
       Latency, traffic, power, energy
```

### 2.1 Trace generation

The scripts under [`trace-generator/`](./trace-generator/) convert token-length distributions or dataset statistics into CSV request traces.

A trace row represents one individual request. It commonly contains information such as:

- Input/prompt token count
- Expected output token count
- Request or sequence identifier
- Assigned memory/PIM channel, depending on the trace-generation mode

The trace itself normally describes requests; it does not by itself define the runtime batch. Runtime batching is performed later by the simulator scheduler.

Channel assignment is separate from batching:

- `rr`: round-robin channel assignment
- `clb`: channel-load balancing based on estimated traffic/load

### 2.2 Request loading

[`RequestGenerator`](./src/RequestGenerator.cc) reads the CSV trace and exposes the input/output token lengths to the simulator.

The simulator creates request state and tracks request lifecycle information such as:

- Input token count
- Target output token count
- Number of generated tokens
- Current sequence length
- Assigned channel
- Completion status

During autoregressive decoding, the sequence length approximately follows:

```text
current_sequence_length =
    input_tokens + generated_tokens
```

It is bounded by the configured maximum sequence length.

### 2.3 Scheduling and operation generation

The client and scheduler manage which requests are admitted and which operations are ready to execute. The relevant components include:

- [`src/client/Client.cc`](./src/client/Client.cc)
- [`src/BatchedRequest.cc`](./src/BatchedRequest.cc)
- [`src/BatchedRequest.h`](./src/BatchedRequest.h)
- [`src/scheduler/Scheduler.cc`](./src/scheduler/Scheduler.cc)
- [`src/scheduler/NeuPIMScheduler.cc`](./src/scheduler/NeuPIMScheduler.cc)
- [`src/scheduler/NeuPIMScheduler.h`](./src/scheduler/NeuPIMScheduler.h)

The scheduler turns active requests into model operations and tiles. Operations can include:

- Matrix multiplication
- Attention
- Fused multi-head attention
- GEMV
- Softmax
- LayerNorm
- GELU
- Add/projection operations
- KV-cache accesses

### 2.4 NPU execution

NPU operations are scheduled on modeled NPU resources such as:

- Systolic arrays
- Vector units
- Other configured compute resources

The scheduler divides operations into tiles and issues those tiles when their dependencies and hardware resources permit.

### 2.5 PIM/DRAM execution

Memory and PIM operations are sent through [`src/Dram.cc`](./src/Dram.cc) to NewtonSim.

The NewtonSim controller models cycle-level memory behavior, including commands such as:

- Activate
- Read
- Write
- Global write (`GWRITE`)
- Global activate (`G_ACT`)
- Compute (`COMP`)
- Result read (`READRES`)

The relevant controller implementation is [`extern/NewtonSim/src/neupims_controller.cc`](./extern/NewtonSim/src/neupims_controller.cc).

PIM is especially useful for memory-intensive attention/KV-cache work because computation can be performed close to the data.

### 2.6 Cycle simulation

The simulator advances time cycle by cycle. During the simulation it advances or checks:

- NPU resources
- Interconnects
- Scheduler queues
- Request dependencies
- DRAM/PIM controllers
- Operation completion
- Request completion

The simulator loop is implemented in [`src/Simulator.cc`](./src/Simulator.cc).

---

## 3. How latency and power are generated

### 3.1 Latency

Latency is derived from simulated timing rather than from a static formula.

The simulator tracks when work becomes ready, when it is issued, when dependencies finish, and when the request completes. Request latency is therefore affected by:

- Number of input and output tokens
- Sequence length growth
- NPU operation duration
- PIM/DRAM access latency
- Queueing and scheduling delays
- Dependency chains
- Memory-channel contention
- Sub-batch scheduling
- Other active requests

Conceptually:

```text
request latency =
    completion cycle - request arrival/start cycle
```

The simulator statistics and logging code is located in files such as:

- [`src/Stat.h`](./src/Stat.h)
- [`src/Stats.cpp`](./src/Stats.cpp)
- [`src/Logger.h`](./src/Logger.h)

### 3.2 Power and energy

NewtonSim provides detailed DRAM/PIM timing and power or energy accounting. Counters are associated with memory/PIM commands such as activation, read, write, compute, and result-read operations.

The memory/PIM power model is more explicit in the repository than a complete NPU/SRAM/interconnect power model. Therefore, power results should be interpreted according to which modeled components and counters are enabled in the selected configuration.

The general process is:

```text
Issued DRAM/PIM commands
          |
          v
Command timing and activity counters
          |
          v
Per-command energy/power accounting
          |
          v
Total memory/PIM power and energy statistics
```

---

## 4. Request lifecycle and ordinary batching

The request lifecycle can be viewed as:

```text
CSV request
     |
     v
initiated request
     |
     v
queued/waiting request
     |
     v
ongoing/active request
     |
     v
completed request
```

An active request is admitted to the simulator, has not completed, and is eligible for model-operation scheduling. It does not necessarily consume hardware on every cycle; it may be:

- Running on the NPU
- Waiting for PIM/DRAM
- Waiting for a dependency
- Waiting for scheduler service

### 4.1 Batch admission

The scheduler admits waiting requests until configured capacity is reached. Important configuration concepts include:

- `max_batch_size`
- `max_active_reqs`
- `max_seq_len`
- `sub_batch_mode`
- `ch_load_balancing`
- `kernel_fusion`

If a trace contains 512 requests but the current configuration allows a batch of 128, the simulator does not process all 512 as one active group:

```text
Active request set:
    R1 ... R128

Waiting queue:
    R129 ... R512
```

### 4.2 Dynamic replacement

The simulator can replace completed requests with waiting requests instead of always waiting for the entire original group to finish.

Example:

```text
Initial active set:
    R1 R2 R3 R4

Waiting queue:
    R5 R6 R7 ...

R2 completes:
    active = R1 R3 R4

R5 is admitted:
    active = R1 R3 R4 R5
```

This behavior is commonly described as continuous or dynamic batching.

### 4.3 Different request lengths

Requests in the same active set do not need to have equal lengths. For example:

```text
R1: input = 100, output = 20
R2: input = 500, output = 5
R3: input = 32,  output = 200
R4: input = 256, output = 50
```

Each request maintains its own sequence length:

```text
R1: 100 -> 101 -> 102 -> ...
R2: 500 -> 501 -> 502 -> ...
R3: 32  -> 33  -> 34  -> ...
R4: 256 -> 257 -> 258 -> ...
```

This means the requests can have different KV-cache lengths and different amounts of attention work while sharing the same active scheduling context.

---

## 5. What is the active request set?

The active request set is the collection of requests that have been admitted into the simulator and are currently unfinished.

It is not the full trace:

```text
All requests in CSV
        |
        v
Waiting/queued requests
        |
        v
Active request set
        |
        v
Completed requests
```

Example:

```text
Trace:
    R1 R2 R3 R4 R5 R6 R7 R8 R9 R10

Active request set:
    R1 R2 R3 R4

Waiting queue:
    R5 R6 R7 R8 R9 R10
```

The active requests are the ones for which the simulator can generate and schedule operations such as attention, matrix multiplication, GEMV, softmax, LayerNorm, and KV-cache accesses.

### Active set versus a request executing now

These are not identical:

```text
Active request:
    admitted, unfinished, and eligible for future scheduling

Currently executing request:
    actually using a hardware resource at this cycle
```

An active request may temporarily wait for memory, a dependency, or a scheduler slot.

---

## 6. Why sub-batching was introduced

NeuPIMs models heterogeneous resources. NPU work and PIM/DRAM work have different timing and resource behavior:

```text
NPU:
    matrix multiplication, LayerNorm, GELU, projections

PIM/DRAM:
    KV-cache accesses, GEMV, attention-related memory operations
```

If a large active batch is treated as one indivisible scheduling group, one resource can become idle while the other is busy or while the full group waits for a slow dependency.

Sub-batching helps the scheduler:

1. Overlap NPU and PIM activity
2. Reduce idle hardware cycles
3. Avoid waiting for the slowest request in a large group
4. Control outstanding memory/KV-cache traffic
5. Improve progress and potentially reduce tail latency

The key idea is:

```text
Large active request set
        |
        +--> smaller sub-batch 0
        |
        +--> smaller sub-batch 1
        |
        +--> interleaved scheduling
```

Sub-batching is a scheduling optimization. It does not change the Transformer mathematics or split a request's tokens into separate user requests.

---

## 7. How sub-batching works

Suppose the active request set contains eight requests:

```text
Active set:
    R1 R2 R3 R4 R5 R6 R7 R8
```

The scheduler can organize them into smaller groups:

```text
Sub-batch 0:
    R1 R2 R3 R4

Sub-batch 1:
    R5 R6 R7 R8
```

The logical active batch remains eight requests, but the scheduler works on smaller groups:

```text
Logical batch size = 8
Sub-batch size     = 4
Number of groups   = 2
```

Sub-batching does not split an individual request:

```text
R1 is not divided into half of its tokens.
R2 is not converted into two separate requests.
```

Instead, complete requests are selected together for a scheduling phase.

### 7.1 Configuration

The behavior is selected through system configuration files:

- [`configs/system_configs/sub-batch-on.json`](./configs/system_configs/sub-batch-on.json)
- [`configs/system_configs/sub-batch-off.json`](./configs/system_configs/sub-batch-off.json)

Conceptually:

```json
{
    "sub_batch_mode": true
}
```

enables sub-batch scheduling, while:

```json
{
    "sub_batch_mode": false
}
```

uses normal full-batch scheduling.

The value is read during initialization and used by the scheduler to select or rotate the current sub-batch.

### 7.2 Scheduling sequence

The simplified sequence is:

```text
1. Read requests from the trace.
2. Admit requests until batch/active-request limits are reached.
3. Form the active request set.
4. Split or select portions of the active set as sub-batches.
5. Schedule operations for the current sub-batch.
6. Issue NPU and PIM tiles.
7. Switch to another sub-batch.
8. Continue until requests finish.
9. Remove completed requests.
10. Admit waiting replacement requests.
```

Example:

```text
Initial active set:
    R1 R2 R3 R4 R5 R6 R7 R8

Select sub-batch 0:
    R1 R2 R3 R4

Execute available operations:
    attention/GEMV/NPU work for R1-R4

Select sub-batch 1:
    R5 R6 R7 R8

Execute available operations:
    attention/GEMV/NPU work for R5-R8

Return to sub-batch 0:
    continue the next available work
```

The exact switching point is determined by the scheduler's operation, dependency, and resource state. The switch is not necessarily only after every request in a sub-batch completely finishes.

### 7.3 Replacement while sub-batching

Sub-batching can work together with dynamic admission:

```text
Sub-batch 0: R1 R2 R3 R4
Sub-batch 1: R5 R6 R7 R8
Waiting:     R9 R10 R11
```

If `R2` completes:

```text
Sub-batch 0: R1 R3 R4
```

The scheduler can admit a replacement:

```text
Sub-batch 0: R1 R3 R4 R9
```

The active set and its sub-batches can therefore evolve while the simulation runs.

---

## 8. Multi-Head Attention (MHA)

MHA means **Multi-Head Attention**. “Multi-head” means that the model performs several independent attention calculations in parallel for the same token sequence.

Instead of using one large attention calculation, the hidden representation is divided into multiple smaller attention subspaces called heads.

### 8.1 Example

Suppose:

```text
hidden_size = 768
num_heads   = 12
```

Each head receives:

```text
head_dimension = hidden_size / num_heads
               = 768 / 12
               = 64
```

Conceptually:

```text
768-dimensional token representation
+---------+---------+---------+-----+
| Head 0  | Head 1  | Head 2  | ... |
| 64 dim  | 64 dim  | 64 dim  |     |
+---------+---------+---------+-----+
```

Each head computes attention independently:

```text
Head 0 -> attention pattern 0
Head 1 -> attention pattern 1
Head 2 -> attention pattern 2
...
Head 11 -> attention pattern 11
```

The results are concatenated:

```text
12 heads * 64 dimensions = 768 dimensions
```

An output projection then combines information from all heads.

### 8.2 Mathematical form

For each head `i`, the model creates query, key, and value matrices:

```text
Q_i = X W_Q_i
K_i = X W_K_i
V_i = X W_V_i
```

The attention result for a head is:

```text
Attention_i(Q_i, K_i, V_i)
    = softmax(Q_i K_i^T / sqrt(d_head)) V_i
```

The multi-head result is:

```text
MHA(X) =
    Concat(head_0, head_1, ..., head_n) W_O
```

Different heads may learn to focus on different relationships, such as:

- Nearby tokens
- Long-distance token relationships
- Subject/verb or other grammatical relationships
- Positional relationships
- Coreference relationships

The model learns these patterns during training; they are not manually assigned.

### 8.3 MHA in NeuPIMs

Attention-related operations are implemented in:

- [`src/operations/Attention.cc`](./src/operations/Attention.cc)
- [`src/operations/FusedMHA.cc`](./src/operations/FusedMHA.cc)
- [`src/operations/PIMGEMV.cc`](./src/operations/PIMGEMV.cc)
- [`src/operations/PIMGEMVSoftmax.cc`](./src/operations/PIMGEMVSoftmax.cc)

PIM is useful for attention operations that access the KV cache, such as:

```text
Q * K^T
softmax
attention weights * V
```

The simulator schedules these operations onto NPU/PIM resources and accounts for their memory traffic and timing.

---

## 9. MHA versus request batching

These are separate dimensions:

```text
Request batching:
    groups independent requests for concurrent scheduling.

Multi-head attention:
    divides each request's hidden representation into attention heads.
```

For example:

```text
Batch dimension:
    R1, R2, R3, R4

Head dimension inside each request:
    Head 0, Head 1, ..., Head 31
```

With:

```text
batch_size = 8
num_heads  = 32
```

there are eight requests and 32 heads per request. The 32 heads are not 32 requests.

The hierarchy is:

```text
Active request set
    |
    +-- Request 1
    |      +-- Head 0
    |      +-- Head 1
    |      +-- ...
    |
    +-- Request 2
    |      +-- Head 0
    |      +-- Head 1
    |      +-- ...
    |
    +-- Request 3
           +-- Head 0
           +-- Head 1
           +-- ...
```

The scheduler chooses the active requests and, when enabled, the current sub-batch. MHA then performs attention work for those selected requests.

```text
Request scheduler
        |
        v
Active request set
        |
        v
Sub-batch selection
        |
        v
MHA/attention operation
        |
        v
NPU/PIM tile scheduling
```

---

## 10. Channel assignment versus batching

Channel assignment and batching must also be kept separate.

```text
Batching:
    Which requests are active together?

Channel assignment:
    Which DRAM/PIM channel handles a request's memory traffic?
```

Example:

```text
Active batch:
    R1 R2 R3 R4

Channel mapping:
    R1 -> channel 0
    R2 -> channel 8
    R3 -> channel 17
    R4 -> channel 25
```

Channel load balancing distributes traffic across memory channels. It does not determine the active request set or the MHA heads.

---

## 11. Complete example

Assume the trace contains ten requests and the configured maximum batch size is four:

```text
Trace:
    R1 R2 R3 R4 R5 R6 R7 R8 R9 R10
```

Initial admission:

```text
Active:
    R1 R2 R3 R4

Waiting:
    R5 R6 R7 R8 R9 R10
```

If sub-batching is enabled:

```text
Sub-batch 0:
    R1 R2

Sub-batch 1:
    R3 R4
```

The scheduler may interleave work:

```text
sub-batch 0 -> NPU/PIM operations
sub-batch 1 -> NPU/PIM operations
sub-batch 0 -> next operations
sub-batch 1 -> next operations
```

If `R2` completes:

```text
Active:
    R1 R3 R4
```

The scheduler admits `R5`:

```text
Active:
    R1 R3 R4 R5
```

The new active set can then be divided into sub-batches again.

Each request separately progresses through its own input and output token sequence, attention/KV-cache work, dependencies, and completion state.

---

## 12. Summary

The main distinctions are:

| Concept | Meaning |
|---|---|
| Request trace | List of individual inference requests |
| Active request set | Currently admitted, unfinished requests |
| Batch | Group of requests allowed to progress together |
| Sub-batch | Smaller scheduling group selected from the active set |
| MHA | Multi-head attention computation inside each request |
| Channel assignment | Mapping request memory traffic to PIM/DRAM channels |
| NPU scheduling | Execution of compute-heavy model operations |
| PIM scheduling | Execution of memory-near operations and KV-cache work |
| Latency | Simulated completion time relative to request start |
| Power/energy | Activity-based accounting for modeled DRAM/PIM commands |

In one sentence:

> NeuPIMs reads individual requests from a trace, admits some of them into an active request set, optionally divides that set into smaller sub-batches for better NPU/PIM overlap, executes MHA and other model operations for the selected requests, and uses cycle-level NPU/DRAM/PIM simulation to obtain latency and power-related statistics.

---

## 13. How tokenization is actually done

The simulator does not tokenize raw text at runtime. Tokenization happens in
the preprocessing script [`trace-generator/tokenize_stat.py`](./trace-generator/tokenize_stat.py).

The preprocessing path is:

```text
Raw conversations
      |
      v
Separate input and output text
      |
      v
Hugging Face `openai-gpt` tokenizer
      |
      v
Count input and output token IDs
      |
      v
Trace-generation scripts write numeric CSV rows
```

For each text string, the script calls the tokenizer and stores the length of
the resulting `input_ids` array. The token IDs themselves are not passed to
the cycle simulator; only lengths are needed for the request-shape model.

At runtime, [`src/RequestGenerator.cc`](./src/RequestGenerator.cc) reads the
numeric CSV. The first column becomes `input_size`, and the configured answer
column becomes the second value returned by `get_qa_length()`. In the current
[`src/client/Client.cc`](./src/client/Client.cc), that second value is used as
the request channel, while `output_size` is currently hard-coded to `1`.
Therefore, “100 words become approximately 130 tokens” is only an estimate;
the exact count depends on the tokenizer, punctuation, whitespace, numbers,
and subword vocabulary.

---

## 14. How batch size affects the model and simulator

Batch size changes the shape and amount of work issued together; it does not
change the learned Transformer weights or the MHA equations.

### 14.1 Larger batches

Increasing the number of requests in a `BatchedRequest` generally:

- increases the number of rows in batched tensors;
- creates more NPU tiles and memory requests in a scheduling phase;
- improves utilization when systolic arrays and vector units would otherwise
  be under-filled;
- amortizes some shared instruction and scheduling overhead;
- increases KV-cache capacity demand and PIM/DRAM traffic;
- increases contention at DRAM channels, interconnect queues, and core queues;
- can increase individual request waiting time and tail latency;
- can improve aggregate throughput until memory or interconnect contention
  becomes the bottleneck.

Prefill is especially sensitive to batch size because each request contributes
its input-token rows. During decoding, each request typically contributes one
new query row, but attention still depends on that request's growing KV-cache
length.

### 14.2 Smaller batches

Decreasing batch size generally reduces simultaneous memory traffic and
queueing, lowers per-request waiting under contention, and can reduce tail
latency. It can also leave systolic arrays, vector units, or DRAM channels
idle and require more scheduling waves for the same trace. The best batch size
is therefore not automatically the largest possible value.

### 14.3 Important current-code caveat

The default system JSON contains:

```text
max_batch_size  = 128
max_active_reqs = 130
```

However, the current constructor in
[`src/scheduler/Scheduler.cc`](./src/scheduler/Scheduler.cc) assigns:

```text
_max_batch_size  = 1024
_max_active_reqs = 1024
```

and leaves the JSON values commented out. Thus, for the current compiled code,
the effective scheduler limits are 1024 and 1024, not 128 and 130. The JSON
values describe the intended experiment configuration but are not currently
wired into those two scheduler fields.

The current scheduler first allocates requests into per-channel active queues.
With `sub_batch_mode=false`, `group_sub_batches()` consolidates all admitted
requests into one request vector. It then creates a
[`BatchedRequest`](./src/BatchedRequest.cc) from that vector. This is the
precise place where the runtime batch is formed; MHA does not choose the
requests.

The code decrements `_active_reqs` when a request is cleaned up, but the
visible `init_batches()` path is entered at the initial stage. Consequently,
the source should not be described as a fully general continuous-batching
implementation without checking the complete experiment path. The earlier
“dynamic replacement” diagram is a useful scheduling concept, but it should
not be treated as proof that every run continuously admits replacements.

---

## 15. Current hardware configuration and scaling effects

The default files describe the following modeled configuration.

| Component | Current value | What it controls |
|---|---:|---|
| NPU cores | 1 | Number of independent modeled NPU cores |
| Core type | `systolic_ws` | Weight-stationary systolic execution |
| Core frequency | 1000 | NPU/core clock |
| Systolic width x height | 128 x 128 | MAC array dimensions and matrix tiling |
| Systolic array count | 8 | Arrays available inside the modeled core |
| Vector cores | 8 | Parallel vector pipelines |
| Vector width | 128 | Elements handled by a vector pipeline group |
| Processing precision | 32-bit process, `precision=2` | Compute and byte-size assumptions |
| DRAM/PIM channels | 32 | Independent memory-channel parallelism |
| DRAM request size | 64 bytes | Memory-request granularity |
| DRAM page size | 1024 bytes | Page and PIM tiling calculations |
| Banks per channel | 32 | Bank-level memory parallelism |
| PIM compute coverage | 16 | Parameters handled by one PIM compute command |
| DRAM frequency | 1000 | Memory-controller clock |
| HBM size | 32 | Parsed memory capacity setting |
| Activation buffer | 512 | Parsed activation-buffer setting |

These values come from
[`configs/systolic_ws_128x128_dev.json`](./configs/systolic_ws_128x128_dev.json)
and [`configs/memory_configs/neupims.json`](./configs/memory_configs/neupims.json).
Detailed HBM timing, queue, and power parameters come from
[`extern/NewtonSim/configs/HBM2_8Gb_x128_dualpim.ini`](./extern/NewtonSim/configs/HBM2_8Gb_x128_dualpim.ini).

### 15.1 Systolic-array changes

Increasing array width or height can reduce matrix tiles and compute time when
matrices are large and align well with the new dimensions. It can have little
benefit when matrices are small, dimensions are unaligned, the array waits for
loads/stores, or DRAM/PIM is already the bottleneck.

Larger arrays can increase local-storage and data-movement pressure. Smaller
arrays generally increase tiling and wave count, which can increase compute
cycles but may avoid underutilization on small operations.

Increasing `systolic_array_count` provides more parallel compute capacity only
if issue logic, SRAM bandwidth, and the memory system can feed the extra
arrays. Otherwise, the additional arrays are underutilized.

The modeled systolic pipeline has a structural compute component based on
`core_height + core_width - 2` plus instruction size. Changing dimensions
therefore changes both tiling and pipeline timing.

Increasing vector-core count or vector width can reduce LayerNorm, GELU,
softmax, add, and other elementwise cycles, until vector work is no longer on
the critical path. The configured scalar/vector operation latencies are mostly
one cycle, so memory movement and pipeline availability may dominate instead.

### 15.2 PIM and DRAM changes

Increasing DRAM/PIM channels can improve throughput when requests are
distributed across channels. It does not guarantee a speedup if channel
assignment is imbalanced or the NPU/interconnect is limiting progress.
NeuPIMs enables channel-load balancing in the default system configuration.

Increasing `pim_comp_coverage` from 16 means each PIM compute command covers
more parameters, so fewer `COMP` commands may be needed. The benefit depends
on tensor layout, alignment, and whether PIM compute or data movement is the
critical path. Decreasing it has the opposite effect.

Changing page size, banks per channel, or request size changes the tiling and
address mapping used by attention and KV-cache operations. These changes can
alter row-buffer locality, bank/channel contention, number of requests, and
PIM command counts simultaneously.

NewtonSim's HBM configuration includes timing values, queue sizes, and current
and voltage values. Timing changes affect completion cycles; power-section
changes affect activity-based energy or power estimates. They do not
automatically change the NPU compute model.

---

## 16. How interconnect/link changes affect results

The NPU and memory nodes communicate through an interconnect. In the simple
implementation, the node count is:

```text
num_cores * dram_channels + dram_channels
```

With the current configuration this is `1 * 32 + 32 = 64` nodes. The
interconnect uses input/output buffering, destination-busy tracking, round
robin source traversal, and separate SA/PIM memory-request queues.

### 16.1 Latency and frequency

Increasing `icnt_latency` delays a request crossing the interconnect. This can
increase NPU load-use stalls, PIM completion time, queue occupancy, and
end-to-end request latency. Decreasing it helps until DRAM/PIM or compute
becomes the bottleneck.

The core-cycle conversion is:

```text
core_cycles = interconnect_cycles * core_freq / icnt_freq
```

Changing `icnt_freq` changes the relation between interconnect and core time
domains. It should not be interpreted as free bandwidth: the interconnect
queues and arbitration must also be able to use the added cycles.

### 16.2 Bandwidth, queues, and topology

Increasing link bandwidth or queue capacity can reduce backpressure and
contention when many SA/PIM requests target the same memory or core. Reducing
them can hold requests in the core or interconnect, increasing stalls and
possibly causing head-of-line blocking.

Changing topology, radix, number of ports, or link count changes the path and
number of arbitration points. Fewer hops can reduce latency; more parallel
paths can improve throughput under load. The result depends on whether traffic
is uniform or concentrated on a subset of channels.

### 16.3 Important current-code caveat

Although the NPU JSON contains:

```text
icnt_type        = simple
icnt_latency     = 1
icnt_freq        = 2000
icnt_config_path = ../configs/booksim2_configs/fly_c64_m8.icnt
```

[`src/Simulator.cc`](./src/Simulator.cc) currently constructs
`SimpleInterconnect` directly. The BookSim2 construction branch is commented
out, and the referenced `.icnt` file is not present at the expected location
in this checkout. Consequently, changing BookSim topology or link parameters
will not affect the current executable unless BookSim2 construction is enabled
and its configuration path is made valid.

For the current run, the meaningful link knobs are the simple interconnect's
latency, frequency, buffering, arbitration, and request-queue behavior.

---

## 17. Recommended comparison method

To study one hardware change at a time:

1. Keep the same model configuration and request trace.
2. Change only one parameter, such as batch limit, array dimension,
   `dram_channels`, `pim_comp_coverage`, or `icnt_latency`.
3. Record total core cycles and per-request completion latency.
4. Record NPU utilization, DRAM bandwidth utilization, PIM cycles, queue
   pressure, and command/energy statistics.
5. Check whether the bottleneck moved from compute to memory, PIM, or
   interconnect.

A faster component that is not on the critical path will produce little
end-to-end improvement. Conversely, a small increase in batch size or link
latency can produce a large tail-latency increase when queues are near full.
