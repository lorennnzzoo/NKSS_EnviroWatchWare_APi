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
    }
}
