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
        public NotificationController(NotificationService _notificationService)
        {
            notificationService = _notificationService;
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
    }
}
