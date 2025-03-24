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
        private readonly string contractsGroupName = "NotificationSubscription";
        public NotificationService(ConfigSettingService _configSettingService, ChannelService _channelService, StationService _stationService)
        {
            configSettingService = _configSettingService;
            channelService = _channelService;
            stationService = _stationService;
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
            return configSettingService.GetConfigSettingsByGroupName(contractsGroupName);
        }
    }
}
