<template>
  <div class="traffic-warning-trigger">
    <n-button circle secondary class="mac-style-button" @click="showDrawer = true">
      <template #icon>
        <i class="iconfont ri-information-line"></i>
      </template>
    </n-button>
  </div>

  <n-drawer
    v-model:show="showDrawer"
    :width="isMobile ? '100%' : '800px'"
    :height="isMobile ? '100%' : '100%'"
    :placement="isMobile ? 'bottom' : 'right'"
    @after-leave="handleDrawerClose"
    :z-index="999999999"
    :mask-closable="false"
  >
    <n-drawer-content
      title="欢迎使用 FinderMusicPlayer"
      closable
      :native-scrollbar="false"
      class="mac-style-drawer"
    >
      <div class="drawer-container">
        <div class="warning-content">
          <div class="support-section">
            <h4>支持项目</h4>
            <p class="support-desc">您的支持是我们持续改进的动力</p>
            <div class="payment-options">
              <div class="payment-option">
                <div class="payment-icon wechat">
                  <img src="@/assets/wechat.png" alt="微信支付" />
                </div>
                <span>微信支付</span>
              </div>
              <div class="payment-option">
                <div class="payment-icon alipay">
                  <img src="@/assets/alipay.png" alt="支付宝" />
                </div>
                <span>支付宝</span>
              </div>
            </div>
          </div>

          <div class="drawer-actions">
            <n-button secondary class="action-button" @click="markAsDonated">已支持</n-button>
            <n-button type="primary" class="action-button primary" @click="remindLater"
              >稍后提醒</n-button
            >
          </div>
        </div>
      </div>
    </n-drawer-content>
  </n-drawer>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';

import { isMobile } from '@/utils';

// 控制抽屉显示状态
const showDrawer = ref(false);

// 处理抽屉关闭后的操作
const handleDrawerClose = () => {
  // 抽屉关闭后的逻辑
};

// 一天后提醒
const remindLater = () => {
  const now = new Date();
  localStorage.setItem('trafficDonated4RemindLater', now.toISOString());
  showDrawer.value = false;
};

// 标记为已捐赠（永久不再提示）
const markAsDonated = () => {
  localStorage.setItem('trafficDonated4Never', '1');
  showDrawer.value = false;
};
// 组件挂载时检查是否需要显示
onMounted(() => {
  // 优先判断是否永久不再提示
  if (localStorage.getItem('trafficDonated4Never')) return;

  // 判断一天后提醒
  const remindLaterTime = localStorage.getItem('trafficDonated4RemindLater');
  if (remindLaterTime) {
    const lastRemind = new Date(remindLaterTime);
    const now = new Date();
    const hoursDiff = (now.getTime() - lastRemind.getTime()) / (1000 * 60 * 60);
    if (hoursDiff < 24) return;
  }

  // 延迟20秒显示
  setTimeout(() => {
    showDrawer.value = true;
  }, 20000);
});
</script>

<style scoped lang="scss">
.traffic-warning-trigger {
  display: inline-block;

  .mac-style-button {
    background-color: rgba(0, 0, 0, 0.05);
    color: #333;
    transition: all 0.2s ease;

    &:hover {
      background-color: rgba(0, 0, 0, 0.1);
    }
  }
}

.mac-style-drawer {
  border-radius: 10px 0 0 10px;
  overflow: hidden;
  position: relative;
}

.drawer-container {
  padding: 20px;
  height: 100%;
  display: flex;
  flex-direction: column;
}

.warning-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 24px;
}

.support-section {
  width: 100%;
  text-align: center;

  h4 {
    font-size: 22px;
    font-weight: 600;
    color: #333;
    margin-bottom: 8px;
  }

  .support-desc {
    font-size: 15px;
    color: #555;
    margin-bottom: 20px;
  }
}

.payment-options {
  display: flex;
  justify-content: center;
  gap: 100px;
  flex-wrap: wrap;
  padding-bottom: 100px;
}

.payment-option {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;

  .payment-icon {
    width: 220px;
    height: 220px;
    border-radius: 12px;
    overflow: hidden;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);

    img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
  }

  span {
    font-size: 15px;
    color: #444;
  }
}

.drawer-actions {
  display: flex;
  justify-content: center;
  gap: 16px;
  margin-top: 30px;
  width: 100%;
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 10px;
  background-color: #fff;
  z-index: 999999999;

  .action-button {
    min-width: 110px;
    border-radius: 8px;
    font-size: 16px;
    padding: 8px 16px;

    &.primary {
      background-color: #007aff;
      color: white;

      &:hover {
        background-color: #0062cc;
      }
    }
  }
}

@media (max-width: 768px) {
  .payment-option {
    .payment-icon {
      width: 190px;
      height: 190px;
    }
  }

  .drawer-actions {
    flex-wrap: wrap;
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    padding: 10px;
    background-color: #fff;
    z-index: 999999999;

    .action-button {
      flex: 1 0 auto;
    }
  }
}
</style>
