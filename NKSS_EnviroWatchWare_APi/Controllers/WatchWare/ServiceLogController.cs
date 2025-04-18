using Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [Authorize(Roles = "Admin")]
    [RoutePrefix("ServiceLogs")]
    public class ServiceLogController : ApiController
    {
        private readonly ServiceLogsService serviceLogs_service;
        public ServiceLogController(ServiceLogsService _serviceLogs_service)
        {
            serviceLogs_service = _serviceLogs_service;
        }

        [HttpGet]
        [Route("GetPast24HourLogs")]
        public IHttpActionResult Get(string type)
        {
            try
            {
                var logs = serviceLogs_service.Get24HourLogsByType(type);
                if (logs == null)
                    return NotFound();
                return Ok(logs);
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
        [Route("GetLastMinuteLogs")]
        public IHttpActionResult GetLastMinuteLogs(string type)
        {
            try
            {
                var logs = serviceLogs_service.GetLastMinuteLogsByType(type);
                if (logs == null)
                    return NotFound();
                return Ok(logs);
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
        [Route("GetSoftwareTypes")]
        public IHttpActionResult Get()
        {
            try
            {
                var types = serviceLogs_service.GetTypes();
                if (types == null)
                    return NotFound();
                return Ok(types);
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
