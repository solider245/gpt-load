package config

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"io"
	"os"
	"strings"

	"gpt-load/internal/types"

	"github.com/sirupsen/logrus"
)

// SecureConfigManager 安全配置管理器
type SecureConfigManager struct {
	baseManager     *Manager
	encryptionKey   []byte
	configSync      *ConfigSync
	logger          *logrus.Entry
}

// NewSecureConfigManager 创建安全配置管理器
func NewSecureConfigManager(baseManager *Manager, configSync *ConfigSync) (*SecureConfigManager, error) {
	// 获取加密密钥
	key := os.Getenv("CONFIG_ENCRYPTION_KEY")
	if key == "" {
		// 如果没有配置加密密钥，生成一个警告
		logrus.Warn("CONFIG_ENCRYPTION_KEY 未配置，敏感配置将以明文存储")
		key = "default-encryption-key-change-in-production"
	}
	
	// 确保密钥长度为32字节（AES-256）
	if len(key) < 32 {
		// 填充密钥到32字节
		padding := make([]byte, 32-len(key))
		key = key + string(padding)
	} else if len(key) > 32 {
		key = key[:32]
	}
	
	return &SecureConfigManager{
		baseManager:   baseManager,
		encryptionKey: []byte(key),
		configSync:    configSync,
		logger:        logrus.WithField("component", "secure_config"),
	}, nil
}

// EncryptDatabaseConfig 加密数据库配置
func (scm *SecureConfigManager) EncryptDatabaseConfig(dsn string) (string, error) {
	if dsn == "" {
		return "", nil
	}
	
	// 检查是否已经是加密的格式
	if strings.HasPrefix(dsn, "encrypted:") {
		return dsn, nil
	}
	
	// 加密DSN
	encrypted, err := scm.encrypt(dsn)
	if err != nil {
		return "", fmt.Errorf("加密数据库配置失败: %w", err)
	}
	
	return "encrypted:" + encrypted, nil
}

// DecryptDatabaseConfig 解密数据库配置
func (scm *SecureConfigManager) DecryptDatabaseConfig(encryptedDSN string) (string, error) {
	if encryptedDSN == "" {
		return "", nil
	}
	
	// 检查是否是加密的格式
	if !strings.HasPrefix(encryptedDSN, "encrypted:") {
		return encryptedDSN, nil
	}
	
	// 提取加密部分
	encryptedPart := strings.TrimPrefix(encryptedDSN, "encrypted:")
	
	// 解密
	decrypted, err := scm.decrypt(encryptedPart)
	if err != nil {
		return "", fmt.Errorf("解密数据库配置失败: %w", err)
	}
	
	return decrypted, nil
}

// GetSecureDatabaseConfig 获取安全的数据库配置
func (scm *SecureConfigManager) GetSecureDatabaseConfig() (types.DatabaseConfig, error) {
	// 从基础管理器获取配置
	config := scm.baseManager.GetDatabaseConfig()
	
	// 解密DSN
	decryptedDSN, err := scm.DecryptDatabaseConfig(config.DSN)
	if err != nil {
		return types.DatabaseConfig{}, err
	}
	
	return types.DatabaseConfig{
		DSN: decryptedDSN,
	}, nil
}

// UpdateDatabaseConfig 更新数据库配置
func (scm *SecureConfigManager) UpdateDatabaseConfig(newDSN string) error {
	// 加密新的DSN
	encryptedDSN, err := scm.EncryptDatabaseConfig(newDSN)
	if err != nil {
		return fmt.Errorf("加密数据库配置失败: %w", err)
	}
	
	// 创建配置更新
	updates := map[string]interface{}{
		"database_dsn": encryptedDSN,
	}
	
	// 通过配置同步服务更新
	if scm.configSync != nil {
		if err := scm.configSync.UpdateSettings(updates); err != nil {
			return fmt.Errorf("同步配置更新失败: %w", err)
		}
	}
	
	scm.logger.Info("数据库配置已更新并同步到所有实例")
	return nil
}

// encrypt 加密数据
func (scm *SecureConfigManager) encrypt(plaintext string) (string, error) {
	block, err := aes.NewCipher(scm.encryptionKey)
	if err != nil {
		return "", err
	}
	
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	
	nonce := make([]byte, gcm.NonceSize())
	if _, err = io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}
	
	ciphertext := gcm.Seal(nonce, nonce, []byte(plaintext), nil)
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// decrypt 解密数据
func (scm *SecureConfigManager) decrypt(ciphertext string) (string, error) {
	data, err := base64.StdEncoding.DecodeString(ciphertext)
	if err != nil {
		return "", err
	}
	
	block, err := aes.NewCipher(scm.encryptionKey)
	if err != nil {
		return "", err
	}
	
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	
	nonceSize := gcm.NonceSize()
	if len(data) < nonceSize {
		return "", fmt.Errorf("ciphertext too short")
	}
	
	nonce, ciphertextData := data[:nonceSize], data[nonceSize:]
	plaintext, err := gcm.Open(nil, nonce, ciphertextData, nil)
	if err != nil {
		return "", err
	}
	
	return string(plaintext), nil
}

// ValidateSecureConfig 验证安全配置
func (scm *SecureConfigManager) ValidateSecureConfig() error {
	// 验证基础配置
	if err := scm.baseManager.Validate(); err != nil {
		return err
	}
	
	// 验证加密密钥
	if string(scm.encryptionKey) == "default-encryption-key-change-in-production" {
		scm.logger.Warn("使用默认加密密钥，请在生产环境中配置 CONFIG_ENCRYPTION_KEY")
	}
	
	// 验证数据库配置
	dbConfig, err := scm.GetSecureDatabaseConfig()
	if err != nil {
		return fmt.Errorf("验证数据库配置失败: %w", err)
	}
	
	if dbConfig.DSN == "" {
		return fmt.Errorf("数据库DSN不能为空")
	}
	
	return nil
}

// RotateEncryptionKey 轮换加密密钥
func (scm *SecureConfigManager) RotateEncryptionKey(newKey string) error {
	// 这里可以实现密钥轮换逻辑
	// 简化版本：只记录日志
	scm.logger.Warn("密钥轮换功能需要实现完整的重新加密流程")
	return fmt.Errorf("密钥轮换功能尚未实现")
}