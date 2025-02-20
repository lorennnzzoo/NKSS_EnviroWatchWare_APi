using Models;
using Post = Models.Post;
using Services;
using System;
using System.Web.Http;
using System.Net.Http;
using System.Net;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [Authorize(Roles = "Admin")]
    [RoutePrefix("MonitoringType")]
    public class MonitoringTypeController : ApiController
    {
        private readonly MonitoringTypeService monitoringType_service;
        private readonly Helpers.Validator validator = new Helpers.Validator();
        public MonitoringTypeController(MonitoringTypeService _monitoringType_service)
        {
            this.monitoringType_service = _monitoringType_service;
        }
        [HttpGet]
        [Route("GetMonitoringType")]
        public IHttpActionResult Get(int id)
        {
            try
            {
                var monitoringType = monitoringType_service.GetMonitoringTypeById(id);
                if (monitoringType == null)
                    return NotFound();
                return Ok(monitoringType);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("GetAllMonitoringTypes")]
        public IHttpActionResult GetAll()
        {
            try
            {
                var monitoringTypes = monitoringType_service.GetAllMonitoringTypes();
                return Ok(monitoringTypes);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [HttpPost]
        [Route("AddMonitoringType")]
        public IHttpActionResult Add(Post.MonitoringType monitoringType)
        {
            try
            {
                //if (monitoringType == null)
                //    return BadRequest("Invalid data.");
                var (isValid, errorMessage) = validator.ValidateProperties(monitoringType);
                if (!isValid)
                {
                    return BadRequest(errorMessage);
                }

                monitoringType_service.CreateMonitoringType(monitoringType);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [HttpPut]
        [Route("UpdateMonitoringType")]
        public IHttpActionResult Update(MonitoringType monitoringType)
        {
            try
            {
                //if (monitoringType == null)
                //    return BadRequest("Invalid data.");
                var (isValid, errorMessage) = validator.ValidateProperties(monitoringType);
                if (!isValid)
                {
                    return BadRequest(errorMessage);
                }

                monitoringType_service.UpdateMonitoringType(monitoringType);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [HttpDelete]
        [Route("DeleteMonitoringType")]
        public IHttpActionResult Delete(int id)
        {
            try
            {
                monitoringType_service.DeleteMonitoringType(id);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }
    }
}
