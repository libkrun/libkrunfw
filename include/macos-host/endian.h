/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef _ENDIAN_H
#define _ENDIAN_H 1

#include <stdint.h>
#include <byteswap.h>

#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__

#define htobe16(x) bswap_16(x)
#define htobe32(x) bswap_32(x)
#define htobe64(x) bswap_64(x)
#define htole16(x) (x)
#define htole32(x) (x)
#define htole64(x) (x)
#define be16toh(x) bswap_16(x)
#define be32toh(x) bswap_32(x)
#define be64toh(x) bswap_64(x)
#define le16toh(x) (x)
#define le32toh(x) (x)
#define le64toh(x) (x)

#else /* Big-endian */

#define htobe16(x) (x)
#define htobe32(x) (x)
#define htobe64(x) (x)
#define htole16(x) bswap_16(x)
#define htole32(x) bswap_32(x)
#define htole64(x) bswap_64(x)
#define be16toh(x) (x)
#define be32toh(x) (x)
#define be64toh(x) (x)
#define le16toh(x) bswap_16(x)
#define le32toh(x) bswap_32(x)
#define le64toh(x) bswap_64(x)

#endif

#endif /* _ENDIAN_H */
