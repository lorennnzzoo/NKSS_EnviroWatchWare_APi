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
                subscriptions.Add(JsonConvert.DeserializeObject<Models.AutoMailReport.ReportSubscription>(setting.ContentValue));
            }
            return subscriptions;
        }
    }
}
