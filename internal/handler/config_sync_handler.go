package handler

import (
	"fmt"
	"net/http"
	"strconv"

	"gpt-load/internal/config"

	"github.com/gin-gonic/gin"
	"github.com/sirupsen/logrus"
)

// ConfigSyncHandler 配置同步处理器
type ConfigSyncHandler struct {
	configSync      *config.ConfigSync
	secureConfig    *config.SecureConfigManager
	settingsManager *config.SystemSettingsManager
}

// NewConfigSyncHandler 创建配置同步处理器
func NewConfigSyncHandler(configSync *config.ConfigSync, secureConfig *config.SecureConfigManager, settingsManager *config.SystemSettingsManager) *ConfigSyncHandler {
	return &ConfigSyncHandler{
		configSync:      configSync,
		secureConfig:    secureConfig,
		settingsManager: settingsManager,
	}
}

// GetConfig 获取当前配置
func (h *ConfigSyncHandler) GetConfig(c *gin.Context) {
	if h.configSync == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"error": "配置同步服务未启用",
		})
		return
	}

	settings := h.configSync.GetSettings()
	c.JSON(http.StatusOK, gin.H{
		"config": settings,
		"status": "success",
	})
}

// UpdateConfig 更新配置
func (h *ConfigSyncHandler) UpdateConfig(c *gin.Context) {
	if h.configSync == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"error": "配置同步服务未启用",
		})
		return
	}

	var updates map[string]interface{}
	if err := c.ShouldBindJSON(&updates); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "无效的请求格式",
		})
		return
	}

	// 验证更新内容
	if err := h.validateUpdates(updates); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": err.Error(),
		})
		return
	}

	// 执行更新
	if err := h.configSync.UpdateSettings(updates); err != nil {
		logrus.WithError(err).Error("配置更新失败")
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "配置更新失败",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "配置更新成功",
		"status":  "success",
	})
}

// UpdateDatabaseConfig 更新数据库配置
func (h *ConfigSyncHandler) UpdateDatabaseConfig(c *gin.Context) {
	if h.secureConfig == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"error": "安全配置管理器未启用",
		})
		return
	}

	var request struct {
		DSN string `json:"dsn" binding:"required"`
	}

	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "无效的请求格式",
		})
		return
	}

	// 更新数据库配置
	if err := h.secureConfig.UpdateDatabaseConfig(request.DSN); err != nil {
		logrus.WithError(err).Error("数据库配置更新失败")
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "数据库配置更新失败",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "数据库配置更新成功",
		"status":  "success",
	})
}

// GetSyncStatus 获取同步状态
func (h *ConfigSyncHandler) GetSyncStatus(c *gin.Context) {
	if h.configSync == nil {
		c.JSON(http.StatusOK, gin.H{
			"enabled": false,
			"status":  "disabled",
		})
		return
	}

	settings := h.configSync.GetSettings()
	c.JSON(http.StatusOK, gin.H{
		"enabled": true,
		"status":  "active",
		"config": gin.H{
			"app_url":                         settings.AppUrl,
			"request_log_retention_days":      settings.RequestLogRetentionDays,
			"request_log_write_interval_minutes": settings.RequestLogWriteIntervalMinutes,
			"request_timeout":                 settings.RequestTimeout,
			"connect_timeout":                 settings.ConnectTimeout,
			"max_retries":                     settings.MaxRetries,
			"blacklist_threshold":             settings.BlacklistThreshold,
		},
	})
}

// validateUpdates 验证配置更新
func (h *ConfigSyncHandler) validateUpdates(updates map[string]interface{}) error {
	for key, value := range updates {
		switch key {
		case "app_url":
			if str, ok := value.(string); !ok || str == "" {
				return fmt.Errorf("app_url 必须是非空字符串")
			}
		case "request_timeout", "connect_timeout", "max_retries", "blacklist_threshold":
			if num, ok := value.(float64); !ok || num < 0 {
				return fmt.Errorf(key + " 必须是非负数")
			}
		case "proxy_keys":
			if _, ok := value.(string); !ok {
				return fmt.Errorf("proxy_keys 必须是字符串")
			}
		default:
			logrus.WithField("key", key).Warn("未知的配置项")
		}
	}
	return nil
}

// ForceSync 强制同步配置
func (h *ConfigSyncHandler) ForceSync(c *gin.Context) {
	if h.configSync == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"error": "配置同步服务未启用",
		})
		return
	}

	// 触发配置重新加载
	if err := h.configSync.UpdateSettings(map[string]interface{}{
		"force_reload": strconv.FormatInt(1, 10),
	}); err != nil {
		logrus.WithError(err).Error("强制同步失败")
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "强制同步失败",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "强制同步成功",
		"status":  "success",
	})
}