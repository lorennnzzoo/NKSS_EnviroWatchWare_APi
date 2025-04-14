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
        private const string CONTACTS_GROUPNAME = "NotificationContacts";
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

        public void CreateContact(ContactType type, string contactAddress)
        {
            
            var contacts = GetContacts(type);
            if (contacts.Any())
            {
                var matchedContact=contacts.Where(e => e.Address.ToLower() == contactAddress.ToLower()).FirstOrDefault();
                if (matchedContact != null)
                {
                    throw new ArgumentException($"Contact already exists : {contactAddress}");
                }               
            }

            Guid contactId = Guid.NewGuid();
            Models.Post.ConfigSetting contact = new Models.Post.ConfigSetting
            {
                GroupName = CONTACTS_GROUPNAME,
                ContentName = type == ContactType.Email ? $"Email_{contactId}" : $"Mobile_{contactId}",
                ContentValue = contactAddress.ToLower(),
            };
            configSettingService.CreateConfigSetting(contact);
        }

        public IEnumerable<Contact> GetContacts(ContactType type)
        {
            List<Contact> contacts = new List<Contact>();
            var settings = configSettingService.GetConfigSettingsByGroupName(CONTACTS_GROUPNAME);
            if (settings.Any())
            {
                if (type == ContactType.Email)
                {
                    var emails = settings.Where(e => e.ContentName.StartsWith("Email_"));
                    if (emails.Any())
                    {
                        foreach(var email in emails)
                        {
                            contacts.Add(new Contact { Id = Guid.Parse(email.ContentName.Replace("Email_","")), Address = email.ContentValue });
                        }
                    }
                }
                else
                {
                    var mobiles = settings.Where(e => e.ContentName.StartsWith("Mobile_"));
                    if (mobiles.Any())
                    {
                        foreach(var mobile in mobiles)
                        {
                            contacts.Add(new Contact { Id = Guid.Parse(mobile.ContentName.Replace("Mobile_","")), Address = mobile.ContentValue });
                        }
                    }
                }
            }
            return contacts;
        }

        public void EditContact(ContactType type, Guid contactId, string contactAddress)
        {
            var settings = configSettingService.GetConfigSettingsByGroupName(CONTACTS_GROUPNAME);
            if (settings.Any())
            {
                if (type == ContactType.Email)
                {
                    var contactToEdit = settings.Where(e => e.ContentName == $"Email_{contactId.ToString()}").FirstOrDefault();
                    if (contactToEdit == null)
                    {
                        throw new ArgumentException("Cannot find contact to edit.");
                    }
                    var contacts = GetContacts(type).Where(e=>e.Id!=contactId);
                    if (contacts.Any())
                    {
                        var matchedContact = contacts.Where(e => e.Address.ToLower() == contactAddress.ToLower()).FirstOrDefault();
                        if (matchedContact != null)
                        {
                            throw new ArgumentException($"Contact already exists : {contactAddress}");
                        }
                    }
                    contactToEdit.ContentValue = contactAddress.ToLower();
                    configSettingService.UpdateConfigSetting(contactToEdit);
                }
                else
                {
                    var contactToEdit = settings.Where(e => e.ContentName == $"Mobile_{contactId.ToString()}").FirstOrDefault();
                    if (contactToEdit == null)
                    {
                        throw new ArgumentException("Cannot find contact to edit.");
                    }
                    var contacts = GetContacts(type).Where(e => e.Id != contactId);
                    if (contacts.Any())
                    {
                        var matchedContact = contacts.Where(e => e.Address.ToLower() == contactAddress.ToLower()).FirstOrDefault();
                        if (matchedContact != null)
                        {
                            throw new ArgumentException($"Contact already exists : {contactAddress}");
                        }
                    }
                    contactToEdit.ContentValue = contactAddress.ToLower();
                    configSettingService.UpdateConfigSetting(contactToEdit);
                }
            }
        }

        public void DeleteContact(ContactType type, Guid contactId)
        {
            var settings = configSettingService.GetConfigSettingsByGroupName(CONTACTS_GROUPNAME);
            if (settings.Any())
            {
                if (type == ContactType.Email)
                {
                    var contactToDelete = settings.Where(e => e.ContentName == $"Email_{contactId.ToString()}").FirstOrDefault();
                    if (contactToDelete == null)
                    {
                        throw new ArgumentException("Cannot find contact to delete.");
                    }
                    configSettingService.DeleteConfigSetting(contactToDelete.Id);
                }
                else
                {
                    var contactToDelete = settings.Where(e => e.ContentName == $"Mobile_{contactId.ToString()}").FirstOrDefault();
                    if (contactToDelete == null)
                    {
                        throw new ArgumentException("Cannot find contact to delete.");
                    }
                    configSettingService.DeleteConfigSetting(contactToDelete.Id);
                }
            }
        }

        public void UpdatePreference(NotificationPreference preference)
        {
            var setting = configSettingService.GetConfigSettingsByGroupName(GROUPNAME).Where(e => e.ContentName == "Preference").FirstOrDefault();
            if (setting != null)
            {
                setting.ContentValue = preference.ToString();
                configSettingService.UpdateConfigSetting(setting);
            }
            else
            {
                Models.Post.ConfigSetting preferenceCreate = new Models.Post.ConfigSetting
                {
                    GroupName = GROUPNAME,
                    ContentName = "Preference",
                    ContentValue = preference.ToString(),
                };

                configSettingService.CreateConfigSetting(preferenceCreate);
            }
        }

        public NotificationPreference GetPreference()
        {
            var setting = configSettingService.GetConfigSettingsByGroupName(GROUPNAME).Where(e => e.ContentName == "Preference").FirstOrDefault();
            if (setting != null)
            {
                if (setting.ContentValue == NotificationPreference.GroupAll.ToString())
                {
                    return NotificationPreference.GroupAll;
                }
                else if(setting.ContentValue == NotificationPreference.GroupByStation.ToString())
                {
                    return NotificationPreference.GroupByStation;
                }
                else
                {
                    return NotificationPreference.OnePerChannel;
                }
            }
            else
            {
                return NotificationPreference.OnePerChannel;
            }
        }

        public void MultiChannelSubscription(List<int> ChannelIds)
        {
            var conditions = GetAllConditions();
            if (conditions.Any())
            {
                foreach (int ChannelId in ChannelIds)
                {
                    var status = GetChannelsStatuses().Where(e => e.ChannelId == ChannelId).FirstOrDefault();
                    if (!status.Subscribed)
                    {
                        Guid subscriptionId = Guid.NewGuid();
                        NotificationSubscription subscription = new NotificationSubscription
                        {
                            Id = subscriptionId,
                            ChannelId = ChannelId,
                            Conditions = conditions.ToList()
                        };
                        Models.Post.ConfigSetting setting = new Models.Post.ConfigSetting
                        {
                            GroupName = GROUPNAME,
                            ContentName = $"Subscription_{subscriptionId}",
                            ContentValue = JsonConvert.SerializeObject(subscription),
                        };
                        configSettingService.CreateConfigSetting(setting);
                    }                    
                }
            }
            else
            {
                throw new ArgumentException("Please create conditions before subscribing.");
            }
        }

        public IEnumerable<ChannelStatus> GetMultiChannelSubscriptionStatus()
        {
            return GetChannelsStatuses().Where(e => e.Subscribed);
        }

        public Condition GetCondition(string id)
        {
            var condition = GetAllConditions().Where(e => e.Id == Guid.Parse(id)).FirstOrDefault();
            return condition;
        }

        public void UpdateCondition(Condition condition)
        {
            var conditionToEdit = configSettingService.GetConfigSettingsByGroupName(GROUPNAME).Where(e => e.ContentName == $"Condition_{condition.Id}").FirstOrDefault();
            if (conditionToEdit == null)
            {
                throw new ArgumentException("Cannot find condition to update.");
            }
            conditionToEdit.ContentValue= JsonConvert.SerializeObject(condition);
            configSettingService.UpdateConfigSetting(conditionToEdit);
        }

        public void DeleteCondition(string id)
        {
            var conditionSetting = configSettingService.GetConfigSettingsByGroupName(GROUPNAME).Where(e => e.ContentName == $"Condition_{id}").FirstOrDefault();
            if (conditionSetting == null)
            {
                throw new ArgumentException("Cannot find subscription to delete.");
            }
            configSettingService.DeleteConfigSetting(conditionSetting.Id);
        }
    }
}
