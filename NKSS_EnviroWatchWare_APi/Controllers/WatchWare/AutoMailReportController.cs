using Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [Authorize]
    [RoutePrefix("AutoMailReport")]
    public class AutoMailReportController : ApiController
    {
        private readonly AutoMailReportService autoMailReportService;
        public AutoMailReportController(AutoMailReportService _autoMailReportService)
        {
            autoMailReportService = _autoMailReportService;
        }
        [HttpPost]
        [Route("CreateSubscription")]
        public IHttpActionResult CreateSubscription(Models.AutoMailReport.ReportSubscription subscription)
        {
            try
            {
                autoMailReportService.CreateSubscription(subscription);
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
        [Route("GetSubscriptions")]
        public IHttpActionResult GetSubscriptions()
        {
            try
            {
                var subscriptions = autoMailReportService.GetSubscriptions();
                if (subscriptions == null)
                {
                    return NotFound();
                }
                return Ok(subscriptions);
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
        [Route("GetSubscription")]
        public IHttpActionResult GetSubscription(string id)
        {
            try
            {
                var subscription = autoMailReportService.GetSubscription(id);
                if (subscription == null)
                {
                    return NotFound();
                }
                return Ok(subscription);
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
        public IHttpActionResult UpdateSubscription(Models.AutoMailReport.ReportSubscription subscription)
        {
            try
            {
                autoMailReportService.UpdateSubscription(subscription);
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
        [Route("DeleteSubscription")]
        public IHttpActionResult DeleteSubscription(string id)
        {
            try
            {
                autoMailReportService.DeleteSubscription(id);
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
    }
}
