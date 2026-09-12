# Hướng dẫn constraints cho PicoRV32

## 1. File được sử dụng

File constraints chính:

`/home/tienpnh/workspace/cadence/RISC-V-PROCESSOR/constraints/picorv32.sdc`

File này được nạp bằng đường dẫn tuyệt đối trong:

`/home/tienpnh/workspace/cadence/RISC-V-PROCESSOR/mmmc.view`

Đơn vị lấy từ Liberty đang sử dụng:

- Thời gian: ns.
- Điện dung: pF.

## 2. Clock

Clock input `clk` được đặt tên là `core_clk`. Cấu hình ban đầu dùng chu kỳ
10 ns, tương ứng 100 MHz, với duty cycle 50%.

```tcl
set CORE_CLOCK_PERIOD_NS 10.00
```

Đổi tần số bằng công thức:

```text
period_ns = 1000 / frequency_MHz
```

| Tần số | Chu kỳ |
|---:|---:|
| 50 MHz | 20 ns |
| 100 MHz | 10 ns |
| 200 MHz | 5 ns |

Clock uncertainty là 0.20 ns cho setup và 0.10 ns cho hold. Đây là margin ban
đầu dành cho jitter và skew, không phải thông số signoff.

## 3. Input delay

Tất cả input ngoại trừ `clk` được constraint so với `core_clk`:

- Max input delay: 1.00 ns cho setup analysis.
- Min input delay: 0.20 ns cho hold analysis.
- Driver giả định: output `Y` của standard cell `BUFX2`.

Không khai báo đồng thời `set_input_transition` trên các data input vì slew
đầu vào sẽ được tính từ mô hình timing của `BUFX2`.

Nhóm này bao gồm `resetn`, memory response, PCPI response và IRQ.

`resetn` active-low nhưng được lấy mẫu trong các khối `always @(posedge clk)`;
do đó đây là reset đồng bộ. SDC constraint nó như data input bình thường và
không đặt false path. Nếu reset được xử lý trong wrapper khác, constraint phải
được cập nhật theo kiến trúc wrapper thực tế.

## 4. Output delay và tải

Tất cả output hiện dùng:

- Max output delay: 1.00 ns.
- Min output delay: -0.20 ns.
- Output load: 0.05 pF.

Min delay âm mô hình hóa yêu cầu hold của thiết bị nhận. Khi có timing thật
của SRAM, interconnect hoặc peripheral, phải thay các giả định này bằng thông
số của khối nhận tương ứng.

## 5. Native memory interface

Các cổng `mem_valid`, `mem_ready`, `mem_addr`, `mem_wdata`, `mem_wstrb` và
`mem_rdata` tạo giao tiếp instruction/data memory chính. SDC hiện giả định core
và memory cùng hoạt động theo `core_clk`.

Các output `mem_la_*` thuộc look-ahead interface và có thể tạo đường tổ hợp dài
hơn giao tiếp `mem_*`; cần xem riêng các đường này trong timing report.

## 6. PCPI và IRQ

Với parameter mặc định, `ENABLE_PCPI`, `ENABLE_MUL`, `ENABLE_FAST_MUL` và
`ENABLE_DIV` đều bằng 0 nên phần lớn logic PCPI có thể được tối ưu bỏ. Nếu bật
coprocessor, cần xác nhận nó dùng `core_clk`; nếu dùng clock khác phải bổ sung
clock và CDC constraints.

`irq[31:0]` hiện được constraint như input đồng bộ. Nếu IRQ thực tế bất đồng
bộ, wrapper SoC phải chứa synchronizer. Không dùng false path để che một CDC
chưa có synchronizer.

## 7. Design-rule constraints

Giới hạn ban đầu:

- Maximum transition: 0.50 ns.
- Maximum fanout: 16.
- Maximum capacitance: 0.20 pF.

Genus và Innovus sẽ chèn hoặc thay buffer để sửa vi phạm khi có thể. Cần hiệu
chỉnh các giá trị này theo mục tiêu timing, công suất và diện tích thực tế.

## 8. Ideal clock và propagated clock

Trong synthesis và pre-CTS, `core_clk` là ideal clock. File SDC chung không đặt
`set_propagated_clock`.

Sau CTS, script Innovus Stylus phải chạy:

```tcl
set_propagated_clock [get_clocks core_clk]
```

Sau đó chạy lại setup/hold analysis với extracted RC.

## 9. Kiểm tra sau khi nạp SDC

Trong Genus Stylus:

```tcl
check_timing_intent
report_clocks
report_timing -max_paths 10
```

Trong Innovus Stylus:

```tcl
get_db analysis_views
report_clocks
report_timing -max_paths 10
```

Cần xử lý các cảnh báo unconstrained endpoint, clock không tới register hoặc
I/O không có delay trước khi đánh giá timing.

## 10. Những thông số phải xác nhận trước signoff

1. Tần số vận hành mục tiêu.
2. Clock jitter và skew budget.
3. Min/max delay của memory, bus và peripheral.
4. Tải thật trên từng output.
5. Clock domain và phương pháp đồng bộ IRQ/PCPI.
6. PVT và RC corners đúng với PDK 45 nm.

CapTbl hiện tại tự nhận dạng là `cln28hpl` 28 nm trong khi Liberty, LEF và QRC
là GPDK045. Nó đang được nạp theo yêu cầu của flow, nhưng kết quả RC từ tổ hợp
này không được xem là dữ liệu signoff 45 nm.
