using Models.Notification;
using Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Interfaces
{
    public interface INotificationService
    {
        IEnumerable<ChannelStatus> GetChannelsStatuses();
        IEnumerable<ConfigSetting> GetSubscriptions();
        Station GetStation(int id);
        void CreateCondition(Models.Notification.Condition condition);
        IEnumerable<Condition> GetAllConditions();
        void GenerateSubscription(Models.Notification.SubscribeRequest subscribeRequest);
        IEnumerable<Condition> GetSubscribedConditionsOfChannel(int channelId);
    }
}
