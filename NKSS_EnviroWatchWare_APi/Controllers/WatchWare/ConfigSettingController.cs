using NKSS_EnviroWatchWare_APi.Helpers;
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
    [RoutePrefix("ConfigSetting")]
    public class ConfigSettingController : ApiController
    {
        private readonly ConfigSettingService config_Setting_Service;
        private readonly Helpers.Validator validator = new Helpers.Validator();
        public ConfigSettingController(ConfigSettingService _config_Setting_Service)
        {
            this.config_Setting_Service = _config_Setting_Service;
        }

        [HttpGet]
        [Route("GetConfigSetting")]
        public IHttpActionResult Get(int id)
        {
            try
            {
                var configSetting = config_Setting_Service.GetConfigSettingById(id);
                if (configSetting == null)
                    return NotFound();
                return Ok(configSetting);
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
        [Route("GetAllConfigSettings")]
        public IHttpActionResult GetAll()
        {
            try
            {
                var configSettings = config_Setting_Service.GetAllConfigSettings();
                return Ok(configSettings);
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
        [Route("AddConfigSetting")]
        public IHttpActionResult Add(Models.Post.ConfigSetting configSetting)
        {
            try
            {
                //if (oxide == null)
                //    return BadRequest("Invalid data.");
                var (isValid, errorMessage) = validator.ValidateProperties(configSetting);
                if (!isValid)
                {
                    return BadRequest(errorMessage);
                }

                config_Setting_Service.CreateConfigSetting(configSetting);
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
        [Route("UpdateConfigSetting")]
        public IHttpActionResult Update(Models.ConfigSetting configSetting)
        {
            try
            {
                //if (oxide == null)
                //    return BadRequest("Invalid data.");
                var (isValid, errorMessage) = validator.ValidateProperties(configSetting);
                if (!isValid)
                {
                    return BadRequest(errorMessage);
                }

                config_Setting_Service.UpdateConfigSetting(configSetting);
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
        [Route("DeleteConfigSetting")]
        public IHttpActionResult Delete(int id)
        {
            try
            {
                config_Setting_Service.DeleteConfigSetting(id);
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
        [Route("GetAllConfigSettingsByGroupName")]
        public IHttpActionResult GetAllByGroupName(string groupName)
        {
            try
            {
                var configSettings = config_Setting_Service.GetConfigSettingsByGroupName(groupName);
                return Ok(configSettings);
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
