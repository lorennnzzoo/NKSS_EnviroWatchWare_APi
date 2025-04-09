using Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [Authorize(Roles ="Admin")]
    [RoutePrefix("Notification")]
    public class NotificationController : ApiController
    {
        private readonly NotificationService notificationService;
        private readonly NotificationHistoryService notificationHistoryService;
        public NotificationController(NotificationService _notificationService, NotificationHistoryService _notificationHistoryService)
        {
            notificationService = _notificationService;
            notificationHistoryService = _notificationHistoryService;
        }
        [HttpGet]
        [Route("GetChannelsStatus")]
        public IHttpActionResult GetChannelsStatus()
        {
            try
            {
                var statuses=notificationService.GetChannelsStatuses();
                if (statuses == null)
                {
                    return NotFound();
                }
                return Ok(statuses);
            }
            catch(Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpPost]
        [Route("CreateCondition")]
        public IHttpActionResult CreateCondition(Models.Notification.Condition condition)
        {
            try
            {
                notificationService.CreateCondition(condition);
                return Ok();
            }
            catch(Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("GetConditions")]
        public IHttpActionResult GetConditions()
        {
            try
            {
                var conditions=notificationService.GetAllConditions();
                if (conditions == null)
                {
                    return NotFound();
                }
                return Ok(conditions);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }
        [HttpPost]
        [Route("Subscribe")]
        public IHttpActionResult Subscribe(Models.Notification.SubscribeRequest subscribeRequest)
        {
            try
            {
                notificationService.GenerateSubscription(subscribeRequest);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpPut]
        [Route("UpdateSubscription")]
        public IHttpActionResult UpdateSubscription(Models.Notification.NotificationSubscription notificationSubscription)
        {
            try
            {
                notificationService.UpdateSubscription(notificationSubscription);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpDelete]
        [Route("Unsubscribe")]
        public IHttpActionResult Unsubscribe(Guid id)
        {
            try
            {
                notificationService.Unsubscribe(id);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("GetSubscriptionOfChannel")]
        public IHttpActionResult GetSubscriptionOfChannel(int channelId)
        {
            try
            {
                var subscription = notificationService.GetSubscriptionOfChannel(channelId);
                if (subscription == null)
                {
                    return NotFound();
                }
                return Ok(subscription);
            }
            catch(Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("GetContacts")]
        public IHttpActionResult GetContacts(Models.Notification.ContactType type)
        {
            try
            {
                var contacts = notificationService.GetContacts(type);
                if (contacts == null)
                {
                    return NotFound();
                }
                return Ok(contacts);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpPost]
        [Route("CreateContact")]
        public IHttpActionResult CreateContact(Models.Notification.ContactCreation creation)
        {
            try
            {
                notificationService.CreateContact(creation.type,creation.address); 
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpPut]
        [Route("EditContact")]
        public IHttpActionResult EditContact(Models.Notification.ContactEdition edition)
        {
            try
            {
                notificationService.EditContact(edition.type, edition.id, edition.address);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpDelete]
        [Route("DeleteContact")]
        public IHttpActionResult DeleteContact(Models.Notification.ContactDeletion deletion)
        {
            try
            {
                notificationService.DeleteContact(deletion.type, deletion.id);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("GetPreference")]
        public IHttpActionResult GetPreference()
        {
            try
            {
                var preference=notificationService.GetPreference();
                return Ok(preference);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }


        [HttpPut]
        [Route("UpdatePreference")]
        public IHttpActionResult UpdatePreference(Models.Notification.UpdatePreference preference)
        {
            try
            {
                notificationService.UpdatePreference(preference.Preference);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }


        [HttpPost]
        [Route("MultiChannelSubscribe")]
        public IHttpActionResult MultiChannelSubscribe(List<int> ChannelIds)
        {
            try
            {
                if (ChannelIds.Count == 0)
                {
                    throw new ArgumentException("Please select atleast one channel to subscribe");
                }
                notificationService.MultiChannelSubscription(ChannelIds);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("LoadMultiChannelSubscriptionStatus")]
        public IHttpActionResult LoadMultiChannelSubscriptionStatus()
        {
            try
            {
                var subscribedChannels = notificationService.GetMultiChannelSubscriptionStatus();
                return Ok(subscribedChannels);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }


        
        [HttpGet]
        [Route("GetAllNotifications")]
        public IHttpActionResult GetAllNotifications()
        {
            try
            {
                var allNotifications = notificationHistoryService.GetAllNotifications();
                if (allNotifications == null)
                {
                    return NotFound();
                }
                return Ok(allNotifications);                
            }
            catch(Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpPut]
        [Route("ReadNotification")]
        public IHttpActionResult ReadNotification(int id)
        {
            try
            {
                notificationHistoryService.ReadNotification(id);
                return Ok();
            }
            catch(Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }
    }
}
