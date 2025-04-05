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
        private const string GROUPNAME = "NotificationGenerator";        
        public NotificationService(ConfigSettingService _configSettingService, ChannelService _channelService, StationService _stationService)
        {
            configSettingService = _configSettingService;
            channelService = _channelService;
            stationService = _stationService;
        }

        public void CreateCondition(Condition condition)
        {
            Guid conditionId = Guid.NewGuid();
            condition.Id = conditionId;
            Models.Post.ConfigSetting settings = new Models.Post.ConfigSetting
            {
                GroupName = GROUPNAME,
                ContentName = $"Condition_{conditionId}",
                ContentValue = JsonConvert.SerializeObject(condition),
            };
            configSettingService.CreateConfigSetting(settings);
        }

        public void GenerateSubscription(SubscribeRequest subscribeRequest)
        {
            Guid subscriptionId = Guid.NewGuid();
            NotificationSubscription subscription = new NotificationSubscription
            {
                Id = subscriptionId,
                ChannelId = subscribeRequest.ChannelId,
                Conditions = subscribeRequest.Conditions
            };
            Models.Post.ConfigSetting setting = new Models.Post.ConfigSetting
            {
                GroupName = GROUPNAME,
                ContentName = $"Subscription_{subscriptionId}",
                ContentValue = JsonConvert.SerializeObject(subscription),
            };
            configSettingService.CreateConfigSetting(setting);
        }

        public IEnumerable<Condition> GetAllConditions()
        {
            List<Condition> conditions = new List<Condition>();
            IEnumerable<ConfigSetting> settings = configSettingService.GetConfigSettingsByGroupName(GROUPNAME).Where(e=>e.ContentName.StartsWith("Condition_"));
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

        public NotificationSubscription GetSubscriptionOfChannel(int channelId)
        {
            List<NotificationSubscription> subscriptions = new List<NotificationSubscription>();            
            IEnumerable<ConfigSetting> settings = configSettingService.GetConfigSettingsByGroupName(GROUPNAME).Where(e=>e.ContentName.StartsWith("Subscription_"));
            foreach(ConfigSetting setting in settings)
            {
                var contentValue = setting.ContentValue;
                NotificationSubscription subscription = JsonConvert.DeserializeObject<NotificationSubscription>(contentValue);
                subscriptions.Add(subscription);
            }
            return subscriptions.Where(e => e.ChannelId == channelId).FirstOrDefault();           
            
        }

        public IEnumerable<ConfigSetting> GetSubscriptions()
        {
            return configSettingService.GetConfigSettingsByGroupName(GROUPNAME).Where(e=>e.ContentName.StartsWith("Subscription_"));
        }

        public void UpdateSubscription(NotificationSubscription notificationSubscription)
        {
            var subscription = GetSubscriptions().Where(e => e.ContentName == $"Subscription_{notificationSubscription.Id}").FirstOrDefault();
            if (subscription == null)
            {
                throw new ArgumentException("Subscription not found.");                
            }
            subscription.ContentValue= JsonConvert.SerializeObject(notificationSubscription);
            configSettingService.UpdateConfigSetting(subscription);
        }

        public void Unsubscribe(Guid id)
        {
            var subscription = GetSubscriptions().Where(e => e.ContentName == $"Subscription_{id}").FirstOrDefault();
            if (subscription == null)
            {
                throw new ArgumentException("Subscription not found.");
            }
            configSettingService.DeleteConfigSetting(subscription.Id);
        }
    }
}
