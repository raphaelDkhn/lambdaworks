#ifndef unsigned_int_h
#define unsigned_int_h

#include <metal_stdlib>
#include "unsigned_int64.h.metal"

template <const uint64_t NUM_LIMBS>
struct UnsignedInteger {
    metal::array<uint32_t, NUM_LIMBS> m_limbs;

    constexpr UnsignedInteger() = default;

    constexpr static UnsignedInteger from_int(uint32_t n) {
        UnsignedInteger res;
        res.m_limbs[NUM_LIMBS - 1] = n;
        return res;
    }

    constexpr static UnsignedInteger from_int(uint64_t n) {
        UnsignedInteger res;
        res.m_limbs[NUM_LIMBS - 2] = (uint32_t)(n >> 32);
        res.m_limbs[NUM_LIMBS - 1] = (uint32_t)(n & 0xFFFF);
        return res;
    }

    constexpr static UnsignedInteger from_bool(bool b) {
        UnsignedInteger res;
        if (b) {
            res.m_limbs[NUM_LIMBS - 1] = 1;
        }
        return res;
    }

    constexpr static UnsignedInteger from_high_low(UnsignedInteger high, UnsignedInteger low) {
        UnsignedInteger res = low;

        for (uint64_t i = 0; i < NUM_LIMBS; i++) {
            res.m_limbs[i] = high.m_limbs[i];
        }

        return res;
    }

    constexpr UnsignedInteger low() const {
        UnsignedInteger res = {m_limbs};

        for (uint64_t i = 0; i < NUM_LIMBS / 2; i++) {
            res.m_limbs[i] = 0;
        }

        return res;
    }

    constexpr UnsignedInteger high() const {
        UnsignedInteger res = {};

        for (uint64_t i = 0; i < NUM_LIMBS / 2; i++) {
            res.m_limbs[NUM_LIMBS / 2 + i] = m_limbs[i];
        }

        return res;
    }

    static UnsignedInteger max() {
        UnsignedInteger res = {};

        for (uint64_t i = 0; i < NUM_LIMBS; i++) {
            res.m_limbs[i] = 0xFFFFFFFF;
        }

        return res;
    }

    constexpr UnsignedInteger64<NUM_LIMBS / 2> to_u64() {
        metal::array<uint64_t, NUM_LIMBS / 2> new_limbs {};

        for (int i = 0; i < (int)NUM_LIMBS / 2; i++) {
            new_limbs[i] = ((uint64_t)m_limbs[i * 2 + 1] << 32) + (uint64_t)m_limbs[i * 2];
        }

        return UnsignedInteger64<NUM_LIMBS / 2> {new_limbs};
    }

    constexpr UnsignedInteger operator+(const UnsignedInteger rhs) const
    {
        metal::array<uint32_t, NUM_LIMBS> limbs {};
        uint64_t carry = 0;
        int i = NUM_LIMBS;

        while (i > 0) {
            uint64_t c = uint64_t(m_limbs[i - 1]) + uint64_t(rhs.m_limbs[i - 1]) + carry;
            limbs[i - 1] = c & 0xFFFFFFFF;
            carry = c >> 32;
            i -= 1;
        }

        return UnsignedInteger<NUM_LIMBS> {limbs};
    }

    constexpr bool operator==(const UnsignedInteger rhs) const
    {
        for (uint32_t i = 0; i < NUM_LIMBS; i++) {
            if (m_limbs[i] != rhs.m_limbs[i]) {
                return false;
            }
        }
        return true;
    }

    constexpr UnsignedInteger operator+=(const UnsignedInteger rhs)
    {
        *this = *this + rhs;
        return *this;
    }

    constexpr UnsignedInteger operator-(const UnsignedInteger rhs) const
    {
        metal::array<uint32_t, NUM_LIMBS> swapped_limbs = swap_limbs(m_limbs);
        metal::array<uint32_t, NUM_LIMBS> rhs_swapped_limbs = swap_limbs(rhs.m_limbs);

        metal::array<uint32_t, NUM_LIMBS> limbs {};
        uint64_t carry = 0;
        uint64_t i = NUM_LIMBS;

        while (i > 0) {
            i -= 1;
            int64_t c = (int64_t)(swapped_limbs[i]) - (int64_t)(rhs_swapped_limbs[i]) + carry;
            limbs[i] = c & 0xFFFFFFFF;
            carry = c < 0 ? -1 : 0;
        }

        metal::array<uint32_t, NUM_LIMBS> res_limbs = swap_limbs(limbs);
        return UnsignedInteger<NUM_LIMBS> {res_limbs};
    }

    constexpr UnsignedInteger operator-=(const UnsignedInteger rhs)
    {
        *this = *this - rhs;
        return *this;
    }

    constexpr metal::array<uint32_t, NUM_LIMBS> swap_limbs(metal::array<uint32_t, NUM_LIMBS> limbs) const {
        metal::array<uint32_t, NUM_LIMBS> swap_limbs {};

        for (uint64_t i = 0; i < NUM_LIMBS / 2; i++) {
            swap_limbs[i * 2] = limbs[i * 2 + 1];
            swap_limbs[i * 2 + 1] = limbs[i * 2];
        }

        return swap_limbs;
    }

    constexpr UnsignedInteger operator*(const UnsignedInteger rhs) const
    {
        long int INT_NUM_LIMBS = (long int)NUM_LIMBS;
        metal::array<uint32_t, NUM_LIMBS> swapped_limbs = swap_limbs(m_limbs);
        metal::array<uint32_t, NUM_LIMBS> rhs_swapped_limbs = swap_limbs(rhs.m_limbs);

        uint64_t n = 0;
        uint64_t t = 0;

        for (long int i = INT_NUM_LIMBS - 1; i >= 0; i--) {
            if (swapped_limbs[i] != 0) {
                n = INT_NUM_LIMBS - 1 - i;
            }
            if (rhs_swapped_limbs[i] != 0) {
                t = INT_NUM_LIMBS - 1 - i;
            }
        }

        metal::array<uint32_t, NUM_LIMBS> limbs {};

        uint64_t carry = 0;
        for (uint64_t i = 0; i <= t; i++) {
            for (uint64_t j = 0; j <= n; j++) {
                uint64_t uv = (uint64_t)(limbs[NUM_LIMBS - 1 - (i + j)])
                    + (uint64_t)(swapped_limbs[NUM_LIMBS - 1 - j])
                        * (uint64_t)(rhs_swapped_limbs[NUM_LIMBS - 1 - i])
                    + carry;
                carry = uv >> 32;
                limbs[NUM_LIMBS - 1 - (i + j)] = uv & 0xFFFFFFFF;
            }
            if (i + n + 1 < NUM_LIMBS) {
                limbs[NUM_LIMBS - 1 - (i + n + 1)] = carry & 0xFFFFFFFF;
                carry = 0;
            }
        }

        metal::array<uint32_t, NUM_LIMBS> res_limbs = swap_limbs(swapped_limbs);

        return UnsignedInteger<NUM_LIMBS> {res_limbs};
    }

    uint64_t cast(uint32_t n) {
      return ((uint64_t)n) >> 32;
    }

    constexpr UnsignedInteger operator*=(const UnsignedInteger rhs)
    {
        *this = *this * rhs;
        return *this;
    }

    constexpr UnsignedInteger operator<<(const uint32_t rhs) const
    {
        uint32_t limbs_shift = rhs >> 5;
        UnsignedInteger<NUM_LIMBS> result = {};
        if (limbs_shift >= NUM_LIMBS) {
            return result;
        }
        // rhs % 32;
        uint32_t bit_shift = rhs & 0x1F;
        // applying this leaves us the bits lost when shifting
        uint32_t bitmask = 0xFFFFFFFF - (1 << (32 - bit_shift)) + 1;

        result.m_limbs[0] = m_limbs[limbs_shift] << bit_shift;

        for (uint32_t src = limbs_shift; src < NUM_LIMBS - 1; src++) {
            uint32_t dst = src - limbs_shift;
            result.m_limbs[dst] |= m_limbs[src + 1] & bitmask;
            result.m_limbs[dst + 1] = m_limbs[src + 1] << bit_shift;
        }

        return result;
    }

    constexpr UnsignedInteger operator>>(const uint32_t rhs) const
    {
        uint32_t limbs_shift = rhs >> 5;
        UnsignedInteger<NUM_LIMBS> result = {};
        if (limbs_shift >= NUM_LIMBS) {
            return result;
        }
        // rhs % 32;
        uint32_t bit_shift = rhs & 0x1F;
        // applying this leaves us the bits lost when shifting
        uint32_t bitmask = (1 << bit_shift) - 1;

        result.m_limbs[NUM_LIMBS - 1] = m_limbs[NUM_LIMBS - 1 - limbs_shift] >> bit_shift;

        for (int src = NUM_LIMBS - 1 - limbs_shift; src > 0; src++) {
            uint32_t dst = src + limbs_shift;
            result.m_limbs[dst] |= m_limbs[src - 1] & bitmask;
            result.m_limbs[dst - 1] = m_limbs[src - 1] >> bit_shift;
        }

        return result;
    }

    constexpr bool operator>(const UnsignedInteger rhs) const {
      for (uint64_t i = 0; i < NUM_LIMBS; i++) {
        if (m_limbs[i] > rhs.m_limbs[i]) return true;
        if (m_limbs[i] < rhs.m_limbs[i]) return false;
      }

      return false;
    }

    constexpr bool operator>=(const UnsignedInteger rhs) {
      for (uint64_t i = 0; i < NUM_LIMBS; i++) {
        if (m_limbs[i] > rhs.m_limbs[i]) return true;
        if (m_limbs[i] < rhs.m_limbs[i]) return false;
      }

      return true;
    }

    constexpr bool operator<(const UnsignedInteger rhs) const {
      for (uint64_t i = 0; i < NUM_LIMBS; i++) {
        if (m_limbs[i] > rhs.m_limbs[i]) return false;
        if (m_limbs[i] < rhs.m_limbs[i]) return true;
      }

      return false;
    }

    constexpr bool operator<=(const UnsignedInteger rhs) const {
      for (uint64_t i = 0; i < NUM_LIMBS; i++) {
        if (m_limbs[i] > rhs.m_limbs[i]) return false;
        if (m_limbs[i] < rhs.m_limbs[i]) return true;
      }

      return true;
    }
};

#endif /* unsigned_int_h */
