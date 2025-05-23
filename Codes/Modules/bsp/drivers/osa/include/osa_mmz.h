#ifndef _OSA_MMZ_H
#define _OSA_MMZ_H

#include "osa.h"

#define CACHE_LINE_SIZE            (0x40)
#define MMZ_MMZ_NAME_LEN           32
#define MMZ_MMB_NAME_LEN           16

struct mmz_media_memory_zone {
    char name[MMZ_MMZ_NAME_LEN];

    unsigned long gfp;

    unsigned long phys_start;
    unsigned long nbytes;

    struct osa_list_head list;
    union {
        struct device *cma_dev;
        unsigned char *bitmap;
    };
    struct osa_list_head mmb_list;

    unsigned int alloc_type;
    unsigned long block_align;

    void (*destructor)(const void *);
};
typedef struct mmz_media_memory_zone mmz_mmz_t;

#define MMZ_MMZ_FMT_S              "PHYS(0x%08lX, 0x%08lX), GFP=%lu, nBYTES=%luKB,    NAME=\"%s\""
#define mmz_mmz_fmt_arg(p) (p)->phys_start, (p)->phys_start + (p)->nbytes - 1, (p)->gfp, (p)->nbytes / SZ_1K, (p)->name

#define MMZ_MMB_NAME_LEN           16
struct mmz_media_memory_block {
#ifndef MMZ_V2_SUPPORT
    unsigned int id;
#endif
    char name[MMZ_MMB_NAME_LEN];
    struct mmz_media_memory_zone *zone;
    struct osa_list_head list;

    unsigned long phys_addr;
    void *kvirt;
    unsigned long length;

    unsigned long flags;

    unsigned int order;

    int phy_ref;
    int map_ref;
};
typedef struct mmz_media_memory_block mmz_mmb_t;

#define mmz_mmb_kvirt(p) ({mmz_mmb_t *__mmb=(p); OSA_BUG_ON(__mmb==NULL); __mmb->kvirt; })
#define mmz_mmb_phys(p) ({mmz_mmb_t *__mmb=(p); OSA_BUG_ON(__mmb==NULL); __mmb->phys_addr; })
#define mmz_mmb_length(p) ({mmz_mmb_t *__mmb=(p); OSA_BUG_ON(__mmb==NULL); __mmb->length; })
#define mmz_mmb_name(p) ({mmz_mmb_t *__mmb=(p); OSA_BUG_ON(__mmb==NULL); __mmb->name; })
#define mmz_mmb_zone(p) ({mmz_mmb_t *__mmb=(p); OSA_BUG_ON(__mmb==NULL); __mmb->zone; })

#define MMZ_MMB_MAP2KERN           (1 << 0)
#define MMZ_MMB_MAP2KERN_CACHED    (1 << 1)
#define MMZ_MMB_RELEASED           (1 << 2)

#define MMZ_MMB_FMT_S              "phys(0x%08lX, 0x%08lX), kvirt=0x%08lX, flags=0x%08lX, length=%luKB,    name=\"%s\""
#define mmz_mmb_fmt_arg(p) (p)->phys_addr, mmz_grain_align((p)->phys_addr + (p)->length) - 1, (unsigned long)(uintptr_t)((p)->kvirt), (p)->flags, (p)->length / SZ_1K, (p)->name

#define DEFAULT_ALLOC              0
#define SLAB_ALLOC                 1
#define EQ_BLOCK_ALLOC             2

#define LOW_TO_HIGH                0
#define HIGH_TO_LOW                1

#define MMZ_DBG_LEVEL              0x0
#define mmz_trace(level, s, params...)                                             \
    do {                                                                           \
        if (level & MMZ_DBG_LEVEL)                                                 \
            printk(KERN_INFO "[%s, %d]: " s "\n", __FUNCTION__, __LINE__, params); \
    } while (0)

#define mmz_trace_func() mmz_trace(0x02, "%s", __FUNCTION__)

#define MMZ_GRAIN                  PAGE_SIZE
#define mmz_bitmap_size(p) (mmz_align2(mmz_length2grain((p)->nbytes), 8) / 8)

#define mmz_get_bit(p, n) (((p)->bitmap[(n) / 8] >> ((n)&0x7)) & 0x1)
#define mmz_set_bit(p, n) (p)->bitmap[(n) / 8] |= 1 << ((n)&0x7)
#define mmz_clr_bit(p, n) (p)->bitmap[(n) / 8] &= ~(1 << ((n)&0x7))

#define mmz_pos2phy_addr(p, n) ((p)->phys_start + (n)*MMZ_GRAIN)
#define mmz_phy_addr2pos(p, a) (((a) - (p)->phys_start) / MMZ_GRAIN)

#define mmz_align2low(x, g) (((x) / (g)) * (g))
#define mmz_align2(x, g) ((((x) + (g)-1) / (g)) * (g))
#define mmz_grain_align(x) mmz_align2(x, MMZ_GRAIN)
#define mmz_length2grain(len) (mmz_grain_align(len) / MMZ_GRAIN)

#define begin_list_for_each_mmz(p, gfp, mmz_name)        \
    osa_list_for_each_entry(p, &mmz_list, list)              \
    {                                                    \
        if (gfp == 0 ? 0 : (p)->gfp != (gfp))            \
            continue;                                    \
        if ((mmz_name == NULL) || (*mmz_name == '\0')) { \
            if (strcmp("anonymous", p->name))            \
                continue;                                \
        } else {                                         \
            if (strcmp(mmz_name, p->name))               \
                continue;                                \
        }                                                \
        mmz_trace(1, MMZ_MMZ_FMT_S, mmz_mmz_fmt_arg(p));
#define end_list_for_each_mmz() }

#if defined(KERNEL_BIT_64) && defined(USER_BIT_32)
#define __phys_addr_type__         unsigned long long
#define __phys_len_type__          unsigned long long
#define __phys_addr_align__        __attribute__((aligned(8)))
#else
#define __phys_addr_type__         unsigned long
#define __phys_len_type__          unsigned long
#define __phys_addr_align__        __attribute__((aligned(sizeof(long))))
#endif

struct mmb_info {
    __phys_addr_type__ phys_addr; /* phys-memory address */
    __phys_addr_type__ __phys_addr_align__ align; /* if you need your phys-memory have special align size */
    __phys_len_type__ __phys_addr_align__ size; /* length of memory you need, in bytes */
    unsigned int __phys_addr_align__ order;

    void *__phys_addr_align__ mapped; /* userspace mapped ptr */

    union {
        struct
        {
            unsigned long prot : 8; /* PROT_READ or PROT_WRITE */
            unsigned long flags : 12; /* MAP_SHARED or MAP_PRIVATE */

#ifdef __KERNEL__
            unsigned long reserved : 8; /* reserved, do not use */
            unsigned long delayed_free : 1;
            unsigned long map_cached : 1;
#endif
        };
        unsigned long w32_stuf;
    } __phys_addr_align__;

    char mmb_name[MMZ_MMB_NAME_LEN];
    char mmz_name[MMZ_MMZ_NAME_LEN];
    unsigned long __phys_addr_align__ gfp; /* reserved, do set to 0 */

#ifdef __KERNEL__
    int map_ref;
    int mmb_ref;

    struct osa_list_head list;
    mmz_mmb_t *mmb;
#endif
} __attribute__((aligned(8)));

struct dirty_area {
    __phys_addr_type__ dirty_phys_start; /* dirty physical address */
    void *__phys_addr_align__ dirty_virt_start; /* dirty virtual  address,
                       must be coherent with dirty_phys_addr */
    __phys_len_type__ __phys_addr_align__ dirty_size;
} __phys_addr_align__;

#define IOC_MMB_ALLOC              _IOWR('m', 10, struct mmb_info)
#define IOC_MMB_ATTR               _IOR('m', 11, struct mmb_info)
#define IOC_MMB_FREE               _IOW('m', 12, struct mmb_info)

#define IOC_MMB_USER_REMAP         _IOWR('m', 20, struct mmb_info)
#define IOC_MMB_USER_REMAP_CACHED  _IOWR('m', 21, struct mmb_info)
#define IOC_MMB_USER_UNMAP         _IOWR('m', 22, struct mmb_info)

#define IOC_MMB_VIRT_GET_PHYS      _IOWR('m', 23, struct mmb_info)

#define IOC_MMB_ADD_REF            _IO('r', 30) /* ioctl(file, cmd, arg), arg is mmb_addr */
#define IOC_MMB_DEC_REF            _IO('r', 31) /* ioctl(file, cmd, arg), arg is mmb_addr */

#define IOC_MMB_FLUSH_DCACHE       _IO('c', 40)

#define IOC_MMB_FLUSH_DCACHE_DIRTY _IOW('d', 50, struct dirty_area)
#define IOC_MMB_TEST_CACHE         _IOW('t', 11, struct mmb_info)

#define MMZ_SETUP_CMDLINE_LEN      256

/*
 * APIs
 */
extern mmz_mmz_t *mmz_mmz_create(const char *name, unsigned long gfp, unsigned long phys_start,
                                 unsigned long nbytes);

extern int mmz_mmz_destroy(mmz_mmz_t *zone);

extern int mmz_mmz_register(mmz_mmz_t *zone);
extern int mmz_mmz_unregister(mmz_mmz_t *zone);
extern mmz_mmz_t *mmz_mmz_find(unsigned long gfp, const char *mmz_name);

extern mmz_mmb_t *mmz_mmb_alloc(const char *name, unsigned long size, unsigned long align,
                                unsigned long gfp, const char *mmz_name);
extern int mmz_mmb_free(mmz_mmb_t *mmb);
extern mmz_mmb_t *mmz_mmb_getby_phys(unsigned long addr);
extern mmz_mmb_t *mmz_mmb_getby_phys_2(unsigned long addr, unsigned long *Outoffset); // used in cipher
extern mmz_mmb_t *mmz_mmb_getby_kvirt(void *virt);
extern unsigned long usr_virt_to_phys(unsigned long virt);

extern int mmz_is_phys_in_mmz(unsigned long addr_start, unsigned long addr_len);

extern int mmz_vma_check(unsigned long vm_start, unsigned long vm_end);
extern int mmz_mmb_flush_dcache_byaddr_safe(void *kvirt, unsigned long phys_addr, unsigned long length);

extern unsigned long mmz_mmz_get_phys(const char *zone_name);

#define mmz_mmb_freeby_phys(phys_addr) mmz_mmb_free(mmz_mmb_getby_phys(phys_addr))

extern void *mmz_mmb_map2kern(mmz_mmb_t *mmb);
extern void *mmz_mmb_map2kern_cached(mmz_mmb_t *mmb);

extern int mmz_mmb_flush_dcache_byaddr(void *kvirt, unsigned long phys_addr, unsigned long length);
extern int mmz_mmb_invalid_cache_byaddr(void *kvirt, unsigned long phys_addr, unsigned long length);

extern int mmz_mmb_unmap(mmz_mmb_t *mmb);
extern int mmz_mmb_get(mmz_mmb_t *mmb);
extern int mmz_mmb_put(mmz_mmb_t *mmb);

extern void *mmz_mmf_map2kern_nocache(unsigned long phys, int len);
extern void *mmz_mmf_map2kern_cache(unsigned long phys, int len);
extern void mmz_mmf_unmap(void *virt);

/* for mmz userdev */
int mmz_userdev_init(void);
void mmz_userdev_exit(void);
int mmz_flush_dcache_all(void);

#endif
