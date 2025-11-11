package uploader

import (
	"bytes"
	"context"
	"fmt"
	"strings"
	"sync"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"github.com/mlogclub/simple/common/strs"

	"bbs-go/internal/models/dto"
)

// MinIO 对象存储（复用腾讯云COS的配置字段）
// 字段映射：
// - Bucket: MinIO Bucket 名称
// - Region: MinIO 服务地址（如 minio.example.com:9000 或 http://minio.example.com:9000）
// - SecretId: MinIO Access Key
// - SecretKey: MinIO Secret Key
type TencentCosUploader struct {
	m          sync.Mutex
	client     *minio.Client
	currentCfg dto.UploadConfig
}

func (u *TencentCosUploader) PutImage(cfg *dto.UploadConfig, data []byte, contentType string) (string, error) {
	if strs.IsBlank(contentType) {
		contentType = "image/jpeg"
	}
	key := generateImageKey(data, contentType)
	return u.PutObject(cfg, key, data, contentType)
}

func (u *TencentCosUploader) PutObject(cfg *dto.UploadConfig, key string, data []byte, contentType string) (string, error) {
	if err := u.initClient(cfg); err != nil {
		return "", err
	}

	ctx := context.Background()
	reader := bytes.NewReader(data)

	_, err := u.client.PutObject(ctx, cfg.TencentCos.Bucket, key, reader, int64(len(data)), minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", err
	}

	// 生成访问 URL
	endpoint := u.cleanEndpoint(cfg.TencentCos.Region)
	useSSL := strings.HasPrefix(cfg.TencentCos.Region, "https://")
	protocol := "http"
	if useSSL {
		protocol = "https"
	}
	
	return fmt.Sprintf("%s://%s/%s/%s", protocol, endpoint, cfg.TencentCos.Bucket, key), nil
}

func (u *TencentCosUploader) CopyImage(cfg *dto.UploadConfig, originUrl string) (string, error) {
	data, contentType, err := download(originUrl)
	if err != nil {
		return "", err
	}
	return u.PutImage(cfg, data, contentType)
}

func (u *TencentCosUploader) initClient(cfg *dto.UploadConfig) error {
	if !u.isCfgChange(cfg) {
		return nil
	}

	u.m.Lock()
	defer u.m.Unlock()

	if cfg != nil {
		endpoint := u.cleanEndpoint(cfg.TencentCos.Region)
		useSSL := strings.HasPrefix(cfg.TencentCos.Region, "https://")

		client, err := minio.New(endpoint, &minio.Options{
			Creds:  credentials.NewStaticV4(cfg.TencentCos.SecretId, cfg.TencentCos.SecretKey, ""),
			Secure: useSSL,
		})
		if err != nil {
			return err
		}

		u.client = client
		u.currentCfg = *cfg
	}

	return nil
}

func (u *TencentCosUploader) isCfgChange(cfg *dto.UploadConfig) bool {
	if cfg == nil || u.client == nil {
		return true
	}

	if u.currentCfg.TencentCos.Bucket != cfg.TencentCos.Bucket ||
		u.currentCfg.TencentCos.Region != cfg.TencentCos.Region ||
		u.currentCfg.TencentCos.SecretId != cfg.TencentCos.SecretId ||
		u.currentCfg.TencentCos.SecretKey != cfg.TencentCos.SecretKey {
		return true
	}

	return false
}

func (u *TencentCosUploader) cleanEndpoint(endpoint string) string {
	endpoint = strings.TrimPrefix(endpoint, "https://")
	endpoint = strings.TrimPrefix(endpoint, "http://")
	return strings.TrimRight(endpoint, "/")
}
