const std = @import("std");
const math = std.math;

pub const Number = f64;

pub const max_safe_integer: Number = (1 << 53) - 1;
pub const min_safe_integer: Number = -max_safe_integer;

pub fn nan() Number {
    return math.nan(f64);
}

pub fn isNaN(n: Number) bool {
    return math.isNan(n);
}

pub fn inf(sign: i32) Number {
    if (sign < 0) {
        return -math.inf(f64);
    }
    return math.inf(f64);
}

pub fn isInf(n: Number) bool {
    return math.isInf(n);
}

fn isNonFinite(x: f64) bool {
    const mask: u64 = 0x7FF0000000000000;
    return (@as(u64, @bitCast(x)) & mask) == mask;
}

pub fn toUint32(x: Number) u32 {
    return @as(u32, @bitCast(toInt32(x)));
}

pub fn toInt32(n: Number) i32 {
    var x = n;

    // Fast path: if the number is in the range (-2^31, 2^32), i.e. an SMI,
    // then we don't need to do any special mapping.
    if (x >= @as(f64, @floatFromInt(std.math.minInt(i32))) and x <= @as(f64, @floatFromInt(std.math.maxInt(i32)))) {
        const smi: i32 = @intFromFloat(x);
        if (@as(f64, @floatFromInt(smi)) == x) {
            return smi;
        }
    }

    if (isNonFinite(x)) {
        return 0;
    }

    x = @trunc(x);
    x = @rem(x, @as(f64, 1 << 32));
    const int64_val: i64 = @intFromFloat(x);
    return @as(i32, @truncate(int64_val));
}

pub fn toShiftCount(x: Number) u32 {
    return toUint32(x) & 31;
}

pub fn signedRightShift(x: Number, y: Number) Number {
    const shift = @as(u5, @intCast(toShiftCount(y)));
    return @as(Number, @floatFromInt(toInt32(x) >> shift));
}

pub fn unsignedRightShift(x: Number, y: Number) Number {
    const shift = @as(u5, @intCast(toShiftCount(y)));
    return @as(Number, @floatFromInt(toUint32(x) >> shift));
}

pub fn leftShift(x: Number, y: Number) Number {
    const shift = @as(u5, @intCast(toShiftCount(y)));
    return @as(Number, @floatFromInt(toInt32(x) << shift));
}

pub fn bitwiseNOT(x: Number) Number {
    return @as(Number, @floatFromInt(~toInt32(x)));
}

pub fn bitwiseOR(x: Number, y: Number) Number {
    return @as(Number, @floatFromInt(toInt32(x) | toInt32(y)));
}

pub fn bitwiseAND(x: Number, y: Number) Number {
    return @as(Number, @floatFromInt(toInt32(x) & toInt32(y)));
}

pub fn bitwiseXOR(x: Number, y: Number) Number {
    return @as(Number, @floatFromInt(toInt32(x) ^ toInt32(y)));
}

pub fn trunc(x: Number) Number {
    return @trunc(x);
}

pub fn floor(x: Number) Number {
    return @floor(x);
}

pub fn abs(x: Number) Number {
    return @abs(x);
}

pub const negative_zero: Number = -0.0;

pub fn remainder(n: Number, d: Number) Number {
    if (isNaN(n) or isNaN(d)) return nan();
    if (isInf(n)) return nan();
    if (isInf(d)) return n;
    if (d == 0) return nan();
    if (n == 0) return n;
    return @rem(n, d);
}

pub fn exponentiate(base: Number, exponent: Number) Number {
    if ((base == 1 or base == -1) and isInf(exponent)) return nan();
    if (base == 1 and isNaN(exponent)) return nan();

    const b = base;
    const e = exponent;

    if (b >= std.math.minInt(i64) and b <= std.math.maxInt(i64) and b == @trunc(b) and
        e >= 0 and e <= std.math.maxInt(i64) and e == @trunc(e) and !isInf(e)) {
        const magnitude = e * @log2(@abs(b));
        if (magnitude > 53 and magnitude <= @log2(std.math.floatMax(f64))) {
            // Not precisely implemented as BigInt for now, fallback to math.pow
        }
    }

    return math.pow(f64, b, e);
}
