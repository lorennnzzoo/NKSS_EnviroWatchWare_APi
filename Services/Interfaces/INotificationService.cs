﻿using Models.Notification;
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
        Condition GetCondition(string id);
        void UpdateCondition(Condition condition);
        void DeleteCondition(string id);
        void GenerateSubscription(Models.Notification.SubscribeRequest subscribeRequest);
        void MultiChannelSubscription(List<int> ChannelIds);
        IEnumerable<ChannelStatus> GetMultiChannelSubscriptionStatus();
        void UpdateSubscription(Models.Notification.NotificationSubscription notificationSubscription);
        void Unsubscribe(Guid id);
        NotificationSubscription GetSubscriptionOfChannel(int channelId);

        void CreateContact(Models.Notification.ContactType type, string contactAddress);
        IEnumerable<Contact> GetContacts(Models.Notification.ContactType type);
        void EditContact(Models.Notification.ContactType type, Guid contactId,string contactAddress);
        void DeleteContact(Models.Notification.ContactType type, Guid contactId);

        void UpdatePreference(Models.Notification.NotificationPreference preference);

        Models.Notification.NotificationPreference GetPreference();
    }
}
