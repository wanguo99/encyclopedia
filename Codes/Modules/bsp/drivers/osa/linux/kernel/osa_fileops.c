#include "osa.h"
#include <linux/version.h>
#include <linux/fs.h>
#include <asm/uaccess.h>

static struct file *klib_fopen(const char *filename, int flags, int mode)
{
    struct file *filp = filp_open(filename, flags, mode);
    return (IS_ERR(filp)) ? NULL : filp;
}

static void klib_fclose(struct file *filp)
{
    if (filp != NULL) {
        filp_close(filp, NULL);
    }
    return;
}

static int klib_fwrite(const char *buf, int len, struct file *filp)
{
    int writelen;

    if (filp == NULL) {
        return -ENOENT;
    }

    writelen = __kernel_write(filp, buf, len, &filp->f_pos);
    return writelen;
}

static int klib_fread(char *buf, unsigned int len, struct file *filp)
{
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 19, 0)
    mm_segment_t old_fs;
    int readlen;
#endif
    if (filp == NULL) {
        return -ENOENT;
    }

#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 19, 0)
    old_fs = get_fs();
    set_fs(get_ds());
    /* The cast to a user pointer is valid due to the set_fs() */
    readlen = vfs_read(filp, (void __user *)buf, len, &filp->f_pos);
    set_fs(old_fs);
    return readlen;
#else
    return kernel_read(filp, (void __user*)buf, len, &filp->f_pos);
#endif
}

void *osa_klib_fopen(const char *filename, int flags, int mode)
{
    return (void *)klib_fopen(filename, flags, mode);
}
EXPORT_SYMBOL(osa_klib_fopen);

void osa_klib_fclose(void *filp)
{
    klib_fclose((struct file *)filp);
}
EXPORT_SYMBOL(osa_klib_fclose);

int osa_klib_fwrite(const char *buf, int len, void *filp)
{
    return klib_fwrite(buf, len, (struct file *)filp);
}
EXPORT_SYMBOL(osa_klib_fwrite);

int osa_klib_fread(char *buf, unsigned int len, void *filp)
{
    return klib_fread(buf, len, (struct file *)filp);
}
EXPORT_SYMBOL(osa_klib_fread);

