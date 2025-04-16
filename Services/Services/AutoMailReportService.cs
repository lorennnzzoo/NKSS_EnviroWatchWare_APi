using Models;
using Models.AutoMailReport;
using Newtonsoft.Json;
using Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services
{
    public class AutoMailReportService : IAutoMailReportService
    {
        private readonly ConfigSettingService configSettingService;
        private readonly ChannelService channelService;
        private readonly StationService stationService;
        private const string GROUPNAME = "AutoMailReportGenerator";
        private const string CONTACTS_GROUPNAME = "NotificationContacts";

        public AutoMailReportService(ConfigSettingService _configSettingService, ChannelService _channelService, StationService _stationService)
        {
            configSettingService = _configSettingService;
            channelService = _channelService;
            stationService = _stationService;
        }

        public void CreateSubscription(ReportSubscription subscription)
        {
            subscription.EmailScheduleTime = new TimeSpan(
                subscription.EmailScheduleTime.Hours,
                subscription.EmailScheduleTime.Minutes,
                0
            );

            Guid subscriptionId = Guid.NewGuid();
            subscription.Id = subscriptionId;
            Models.Post.ConfigSetting setting = new Models.Post.ConfigSetting
            {
                GroupName = GROUPNAME,
                ContentName = $"Subscription_{subscriptionId}",
                ContentValue = JsonConvert.SerializeObject(subscription),
            };
            configSettingService.CreateConfigSetting(setting);
        }

        public IEnumerable<ReportSubscription> GetSubscriptions()
        {
            List<Models.AutoMailReport.ReportSubscription> subscriptions = new List<ReportSubscription>();
            IEnumerable<ConfigSetting> settings = configSettingService.GetConfigSettingsByGroupName(GROUPNAME).Where(e => e.ContentName.StartsWith("Subscription_"));
            foreach (ConfigSetting setting in settings)
            {
                var subscription = JsonConvert.DeserializeObject<Models.AutoMailReport.ReportSubscription>(setting.ContentValue);
                var station = stationService.GetStationById(subscription.StationId);
                if (station != null)
                {
                    subscriptions.Add(subscription);
                }
            }
            return subscriptions;
        }

        public ReportSubscription GetSubscription(string id)
        {
            var subscriptions = GetSubscriptions();
            return subscriptions.Where(e => e.Id ==Guid.Parse( id)).FirstOrDefault();
        }

        public void UpdateSubscription(ReportSubscription subscription)
        {
            var subscriptionSetting = configSettingService.GetConfigSettingsByGroupName(GROUPNAME).Where(e=>e.ContentName== $"Subscription_{subscription.Id}").FirstOrDefault();
            if (subscriptionSetting == null)
            {
                throw new ArgumentException("Cannot find subscription to update.");
            }
            subscriptionSetting.ContentValue = JsonConvert.SerializeObject(subscription);
            configSettingService.UpdateConfigSetting(subscriptionSetting);
        }

        public void DeleteSubscription(string id)
        {
            var subscriptionSetting = configSettingService.GetConfigSettingsByGroupName(GROUPNAME).Where(e => e.ContentName == $"Subscription_{id}").FirstOrDefault();
            if (subscriptionSetting == null)
            {
                throw new ArgumentException("Cannot find subscription to delete.");
            }
            configSettingService.DeleteConfigSetting(subscriptionSetting.Id);
        }
    }
}
