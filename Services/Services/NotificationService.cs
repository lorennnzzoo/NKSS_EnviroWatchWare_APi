using Models;
using Models.Notification;
using Newtonsoft.Json;
using Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services
{
    public class NotificationService : INotificationService
    {
        private readonly ConfigSettingService configSettingService;
        private readonly ChannelService channelService;
        private readonly StationService stationService;
        private readonly string subscriptionsGroupName = "NotificationSubscription";
        private readonly string conditionsGroupName = "NotificationCondition";
        public NotificationService(ConfigSettingService _configSettingService, ChannelService _channelService, StationService _stationService)
        {
            configSettingService = _configSettingService;
            channelService = _channelService;
            stationService = _stationService;
        }

        public void CreateCondition(Condition condition)
        {
            Models.Post.ConfigSetting settings = new Models.Post.ConfigSetting
            {
                GroupName = conditionsGroupName,
                ContentName = $"Condition_{Guid.NewGuid().ToString()}",
                ContentValue = JsonConvert.SerializeObject(condition),
            };
            configSettingService.CreateConfigSetting(settings);
        }

        public void GenerateSubscription(SubscribeRequest subscribeRequest)
        {
            var subscription = new
            {
                ChannelId = subscribeRequest.ChannelId,
                Conditions = subscribeRequest.Conditions
            };
            Models.Post.ConfigSetting setting = new Models.Post.ConfigSetting
            {
                GroupName = subscriptionsGroupName,
                ContentName = $"Subscription_{Guid.NewGuid().ToString()}",
                ContentValue = JsonConvert.SerializeObject(subscription),
            };
            configSettingService.CreateConfigSetting(setting);
        }

        public IEnumerable<Condition> GetAllConditions()
        {
            List<Condition> conditions = new List<Condition>();
            IEnumerable<ConfigSetting> settings = configSettingService.GetConfigSettingsByGroupName(conditionsGroupName);
            foreach(ConfigSetting setting in settings)
            {
                conditions.Add(JsonConvert.DeserializeObject<Condition>(setting.ContentValue));
            }
            return conditions;
        }

        public IEnumerable<ChannelStatus> GetChannelsStatuses()
        {
            IEnumerable<Channel> channels = channelService.GetAllChannels();
            IEnumerable<ConfigSetting> subscriptions = GetSubscriptions();
            var subscribedChannelIds = new HashSet<int>();
            foreach (var subscription in subscriptions)
            {
                var contentValue = JsonConvert.DeserializeObject<NotificationSubscription>(subscription.ContentValue);
                if (contentValue != null)
                {
                    subscribedChannelIds.Add(contentValue.ChannelId);
                }
            }

            
            return channels.Select(channel => new ChannelStatus
            {
                ChannelId = channel.Id.Value,
                ChannelName = channel.Name,
                StationName = GetStation(channel.StationId.Value).Name,
                Units = channel.LoggingUnits,
                Subscribed = subscribedChannelIds.Contains(channel.Id.Value)
            }).ToList();
        }

        public Station GetStation(int id)
        {
            return stationService.GetStationById(id);
        }

        public IEnumerable<ConfigSetting> GetSubscriptions()
        {
            return configSettingService.GetConfigSettingsByGroupName(conditionsGroupName);
        }
    }
}
