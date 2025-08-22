package config

import (
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"gpt-load/internal/store"
	"gpt-load/internal/syncer"
	"gpt-load/internal/types"

	"github.com/sirupsen/logrus"
)

// ConfigSync 配置同步服务
type ConfigSync struct {
	syncer    *syncer.CacheSyncer[types.SystemSettings]
	store     store.Store
	logger    *logrus.Entry
	mu        sync.RWMutex
	callbacks []func(types.SystemSettings)
}

// ConfigUpdate 配置更新消息
type ConfigUpdate struct {
	Timestamp    time.Time              `json:"timestamp"`
	InstanceID   string                 `json:"instance_id"`
	Changes      map[string]interface{} `json:"changes"`
	Version      int64                  `json:"version"`
}

// NewConfigSync 创建配置同步服务
func NewConfigSync(settingsManager *SystemSettingsManager, redisStore store.Store, instanceID string) (*ConfigSync, error) {
	logger := logrus.WithField("component", "config_sync")
	
	// 创建加载函数
	loader := func() (types.SystemSettings, error) {
		settings := settingsManager.GetSettings()
		return settings, nil
	}
	
	// 创建缓存同步器
	syncer, err := syncer.NewCacheSyncer(loader, redisStore, "config_updates", logger, func(newSettings types.SystemSettings) {
		logger.Info("配置已更新，触发回调函数")
	})
	if err != nil {
		return nil, fmt.Errorf("创建配置同步器失败: %w", err)
	}
	
	return &ConfigSync{
		syncer: syncer,
		store:  redisStore,
		logger: logger,
	}, nil
}

// GetSettings 获取当前配置
func (cs *ConfigSync) GetSettings() types.SystemSettings {
	return cs.syncer.Get()
}

// UpdateSettings 更新配置并同步到其他实例
func (cs *ConfigSync) UpdateSettings(updates map[string]interface{}) error {
	cs.mu.Lock()
	defer cs.mu.Unlock()
	
	// 获取当前配置
	currentSettings := cs.GetSettings()
	
	// 应用更新
	if err := applyUpdates(currentSettings, updates); err != nil {
		return fmt.Errorf("应用配置更新失败: %w", err)
	}
	
	// 创建配置更新消息
	update := ConfigUpdate{
		Timestamp:  time.Now(),
		InstanceID: "master", // 可以通过环境变量配置
		Changes:    updates,
		Version:    time.Now().Unix(),
	}
	
	// 序列化更新消息
	updateData, err := json.Marshal(update)
	if err != nil {
		return fmt.Errorf("序列化配置更新失败: %w", err)
	}
	
	// 发布更新到 Redis
	if err := cs.store.Publish("config_updates", updateData); err != nil {
		return fmt.Errorf("发布配置更新失败: %w", err)
	}
	
	cs.logger.Infof("配置更新已发布，影响 %d 个字段", len(updates))
	
	// 触发本地回调
	cs.triggerCallbacks(currentSettings)
	
	return nil
}

// AddCallback 添加配置更新回调
func (cs *ConfigSync) AddCallback(callback func(types.SystemSettings)) {
	cs.mu.Lock()
	defer cs.mu.Unlock()
	cs.callbacks = append(cs.callbacks, callback)
}

// RemoveCallback 移除配置更新回调
func (cs *ConfigSync) RemoveCallback(callback func(types.SystemSettings)) {
	cs.mu.Lock()
	defer cs.mu.Unlock()
	// 注意：在 Go 中无法直接比较函数，这里简化处理
	// 实际应用中可能需要使用函数包装器或其他机制
	cs.callbacks = nil
}

// triggerCallbacks 触发配置更新回调
func (cs *ConfigSync) triggerCallbacks(settings types.SystemSettings) {
	cs.mu.RLock()
	defer cs.mu.RUnlock()
	
	for _, callback := range cs.callbacks {
		go callback(settings)
	}
}

// applyUpdates 应用配置更新
func applyUpdates(settings types.SystemSettings, updates map[string]interface{}) error {
	// 这里可以实现更复杂的配置更新逻辑
	// 简化版本：直接更新配置
	
	// 将 updates 转换为 JSON 再转换回来，确保类型正确
	data, err := json.Marshal(updates)
	if err != nil {
		return fmt.Errorf("序列化更新数据失败: %w", err)
	}
	
	// 这里可以根据需要实现具体的配置更新逻辑
	// 简化版本：记录日志而不实际更新
	logrus.WithField("component", "config_sync").Infof("应用配置更新: %s", string(data))
	
	return nil
}

// Stop 停止配置同步服务
func (cs *ConfigSync) Stop() {
	cs.syncer.Stop()
	cs.logger.Info("配置同步服务已停止")
}